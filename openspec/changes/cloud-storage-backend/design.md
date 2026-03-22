---
id: cloud-storage-backend
artifact: design
---

## Context

The app runs on Raspberry Pi with limited local storage. Currently two independent storage systems exist:

1. **ActiveStorage** (document files: images, audio, PDFs) — Disk service only, configured in `config/storage.yml`
2. **BackupStorage** (SQLite dumps) — custom adapter pattern (`BackupStorage::Base` → `Local` / `S3`), configured via ENV vars (`BACKUP_STORAGE_TYPE`, `BACKUP_S3_*`)

Both systems store data locally by default. S3 support exists only for backups. No OAuth-based cloud provider (Dropbox, Google Drive, OneDrive) is supported for either system.

**Current BackupStorage adapter** (in `app/services/backup_storage/`):

- `Base` — abstract interface: `upload(file_path, key)`, `delete(key)`, `list()`
- `Local` — filesystem (`storage/backups/`)
- `S3` — AWS S3 via `aws-sdk-s3` gem, credentials via `AppSecret`
- `BackupStorage.resolve()` — factory method reading `BACKUP_STORAGE_TYPE` ENV var

**Current ActiveStorage config** (`config/storage.yml`):

- `local:` Disk service (only active service)
- S3 and GCS services commented out

**Constraints:**

- Single-user app — no multi-tenant considerations
- Target deployment: Raspberry Pi (ARM, limited CPU/RAM)
- SQLite database — no concurrent write concerns for settings
- Docker deployment — ENV vars are the primary config mechanism
- Existing `AppSecret` pattern used for sensitive values (reads Rails encrypted credentials)

## Goals / Non-Goals

**Goals:**

- Unified storage provider: one configuration serves both document files and database backups
- Support 5 providers: Local disk, S3/S3-compatible, Dropbox, Google Drive, OneDrive
- Settings UI at `/settings/storage` for provider selection, credentials, and connection testing
- Shared OAuth 2.0 flow for Dropbox, Google Drive, OneDrive
- Migration job: move existing files + backups when switching providers
- Backward compatibility: existing `BACKUP_STORAGE_TYPE` / `BACKUP_S3_*` ENV vars continue working during transition

**Non-Goals:**

- Bidirectional sync with cloud folders
- Browsing cloud storage contents from Inbox
- Multi-cloud mirroring
- End-to-end encryption (rely on provider encryption)
- iCloud / Nextcloud / WebDAV support (v1)
- Local queue for offline resilience (v1 — fail immediately)

## Decisions

### D1: Unified `StorageAdapter` module replaces `BackupStorage`

**Decision:** Create a new `StorageAdapter` module with `Base` class and provider implementations. Both ActiveStorage and BackupService use the same adapter.

**Why not extend existing `BackupStorage`?** The current module is backup-specific (hardcoded `backups/` prefix in S3). A new module with a `namespace:` parameter is cleaner than retrofitting.

**Interface:**

```ruby
StorageAdapter::Base
  upload(file_path, key, namespace:)    # → storage_path (String)
  download(key, namespace:)             # → Tempfile
  delete(key, namespace:)               # → void
  list(namespace:)                      # → Array<String>
  url(key, namespace:, expires_in: 1.hour) # → String (signed URL or local path)
  test_connection()                     # → { ok: true } or raises
```

**`namespace:` parameter:** Separates file categories within the same provider account. Values: `:files`, `:backups`. Maps to directories/prefixes (e.g., `Inbox/files/`, `Inbox/backups/` in Google Drive).

**Factory:**

```ruby
StorageAdapter.resolve  # reads StorageSetting.active, falls back to Local
```

**Alternatives considered:**

- _Keep BackupStorage separate from ActiveStorage:_ Rejected — forces double configuration, potential data split across providers
- _Use ActiveStorage for backups too:_ Rejected — ActiveStorage is designed for blob attachments with DB-tracked metadata, not one-off file dumps. Overkill and fragile for backup use case.

### D2: `StorageSetting` model with single-row pattern

**Decision:** One `storage_settings` row holds the active provider config. If no row exists, default to Local.

**Schema:**

```ruby
create_table :storage_settings do |t|
  t.string  :provider, null: false, default: "local"  # local, s3, dropbox, google_drive, onedrive
  t.text    :config_encrypted                          # encrypted JSON blob
  t.boolean :active, null: false, default: true
  t.string  :status, default: "unchecked"              # unchecked, connected, error
  t.datetime :last_checked_at
  t.timestamps
end
```

**`config_encrypted`** uses Rails `encrypts :config` (ActiveRecord encryption). Contains provider-specific keys:

- S3: `{ access_key_id, secret_access_key, region, bucket, endpoint }`
- Dropbox: `{ refresh_token, access_token, expires_at }`
- Google Drive: `{ refresh_token, access_token, expires_at, folder_id }`
- OneDrive: `{ refresh_token, access_token, expires_at, drive_id, folder_id }`

**Why encrypted column vs AppSecret?** OAuth tokens are dynamic (refreshed at runtime). ENV vars and Rails encrypted credentials are static — unsuitable for tokens that change every few hours. Database encryption keeps tokens secure while allowing runtime updates.

**Alternatives considered:**

- _Store tokens in Rails encrypted credentials:_ Rejected — requires `bin/rails credentials:edit`, can't update at runtime
- _Multiple rows (one per provider):_ Rejected — adds complexity for single-user app. Only one provider active at a time.

### D3: Custom `ActiveStorage::Service::UnifiedStorageService`

**Decision:** Create a single custom ActiveStorage service that delegates all operations to `StorageAdapter.resolve(namespace: :files)`.

```ruby
class ActiveStorage::Service::UnifiedStorageService < ActiveStorage::Service
  def upload(key, io, checksum: nil, **)
    adapter.upload(io, key, namespace: :files)
  end

  def download(key, &block)
    adapter.download(key, namespace: :files)
  end

  # ... delete, exist?, url, etc.

  private
  def adapter
    StorageAdapter.resolve
  end
end
```

**`config/storage.yml`:**

```yaml
unified:
  service: UnifiedStorage

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

When a cloud provider is configured, `ActiveStorage::Blob.service` uses `unified`. When no provider is configured (or provider is `local`), it uses `local` (Disk).

**Why one service class instead of per-provider?** ActiveStorage service config is static YAML. We need dynamic provider switching at runtime. One adapter class that reads from `StorageSetting` avoids rebuilding ActiveStorage config on each provider change.

**Alternatives considered:**

- _Per-provider ActiveStorage services (DropboxService, GoogleDriveService, etc.):_ Rejected — would require modifying `config/storage.yml` and restarting the app on provider change
- _Override `ActiveStorage::Blob.service` dynamically:_ Fragile, monkey-patching Rails internals

### D4: Shared `OAuthManager` service

**Decision:** A single `OAuthManager` class handles OAuth 2.0 flows for all three providers (Dropbox, Google, OneDrive). Provider-specific config (endpoints, scopes) lives in a registry hash.

```ruby
class OAuthManager
  PROVIDERS = {
    dropbox: {
      authorize_url: "https://www.dropbox.com/oauth2/authorize",
      token_url: "https://api.dropboxapi.com/oauth2/token",
      scopes: "files.content.write files.content.read"
    },
    google_drive: {
      authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
      token_url: "https://oauth2.googleapis.com/token",
      scopes: "https://www.googleapis.com/auth/drive.file"
    },
    onedrive: {
      authorize_url: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
      token_url: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
      scopes: "Files.ReadWrite offline_access"
    }
  }

  def authorize_url(provider)
  def handle_callback(provider, code)
  def refresh_access_token(provider, refresh_token)
end
```

**Client ID/secret source:** ENV vars per provider (`DROPBOX_CLIENT_ID`, `DROPBOX_CLIENT_SECRET`, `GOOGLE_DRIVE_CLIENT_ID`, etc.). Consistent with existing `GOOGLE_CLIENT_ID` pattern for Google Calendar.

**Token refresh:** Before each API call, `StorageAdapter` checks `expires_at` in `StorageSetting.config`. If expired, calls `OAuthManager.refresh_access_token` and updates the stored token.

**Alternatives considered:**

- _Per-provider OAuth classes:_ Rejected — 80% of the flow is identical (redirect → callback → exchange code → store token → refresh). Only endpoints and scopes differ.
- _OmniAuth gem:_ Rejected — designed for user authentication, not API authorization. Adds middleware complexity for 3 providers we can handle with simple HTTP calls.

### D5: Provider implementations — API choices

| Provider     | API                 | Gem                                        | Notes                                                                                      |
| ------------ | ------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------ |
| S3           | AWS S3 API          | `aws-sdk-s3` (already in Gemfile)          | Standard, well tested                                                                      |
| Dropbox      | Dropbox API v2      | `dropbox_api`                              | Lightweight Ruby wrapper                                                                   |
| Google Drive | Google Drive API v3 | `google-apis-drive_v3`                     | Official Google gem. Note: _not_ GCS — Drive API is the right choice for personal accounts |
| OneDrive     | Microsoft Graph API | `httpx` (already available) or `Net::HTTP` | No Ruby gem needed — Graph API is REST-based, simple HTTP calls suffice                    |

**Google Drive vs GCS:** GCS requires a Google Cloud project + service account. The target user has a personal Google account, not a GCP setup. Drive API v3 with `drive.file` scope gives access only to files created by the app — minimal permissions, no access to user's other files.

**OneDrive without a gem:** Microsoft Graph API is straightforward REST. Adding a dedicated gem for 4-5 endpoints (upload, download, delete, list, create folder) is overkill. Direct HTTP calls keep dependencies minimal.

### D6: File organization in cloud providers

Each provider gets a root folder for the app:

| Provider     | Root folder           | Files                     | Backups                     |
| ------------ | --------------------- | ------------------------- | --------------------------- |
| S3           | (bucket root)         | `files/<key>`             | `backups/<key>`             |
| Dropbox      | `/Apps/Inbox/`        | `/Apps/Inbox/files/<key>` | `/Apps/Inbox/backups/<key>` |
| Google Drive | `Inbox/` (app folder) | `Inbox/files/<key>`       | `Inbox/backups/<key>`       |
| OneDrive     | `Apps/Inbox/`         | `Apps/Inbox/files/<key>`  | `Apps/Inbox/backups/<key>`  |

Root folders are created automatically on first connection (test_connection action). The folder ID is stored in `StorageSetting.config_encrypted` to avoid repeated lookups.

### D7: BackupService integration

**Decision:** `BackupService` receives its storage adapter via constructor injection (already does this). Change the default from `BackupStorage.resolve` to `StorageAdapter.resolve`.

```ruby
class BackupService
  def initialize(storage: StorageAdapter.resolve)
    @storage = storage
  end

  def perform
    # ... existing logic ...
    storage_path = @storage.upload(temp_path.to_s, key, namespace: :backups)
    # ...
  end
end
```

**Backward compatibility:** If `BACKUP_STORAGE_TYPE=s3` ENV var is set and no `StorageSetting` exists in DB, `StorageAdapter.resolve` falls back to reading legacy ENV vars and creates an S3 adapter. This ensures existing deployments continue working without DB migration.

### D8: Settings UI architecture

**Routes:**

```ruby
namespace :settings do
  resource :storage, only: [:show, :update], controller: "storage" do
    post :test_connection
    get  "oauth/:provider/authorize", action: :oauth_authorize, as: :oauth_authorize
    get  "oauth/:provider/callback",  action: :oauth_callback,  as: :oauth_callback
  end
end
```

**Controller:** `Settings::StorageController` — standard CRUD + OAuth actions.

**UI:**

- Single page at `/settings/storage`
- Provider selector (radio buttons or dropdown): Local, S3, Dropbox, Google Drive, OneDrive
- Conditional form sections per provider:
  - S3: access_key_id, secret_access_key, region, bucket, endpoint fields
  - Dropbox/Google/OneDrive: "Connect" button → OAuth flow → shows "Connected as <name>"
- Test Connection button (all providers)
- Save button
- Migration section (if files exist on old provider): progress bar, start/cancel buttons
- Status indicator: connected/disconnected, last health check

**Styling:** Follows existing app design system (Tailwind utility classes, design tokens from `design_system.tailwind.css`).

## Risks / Trade-offs

**[Risk] OAuth token expiry during long operations** → Mitigation: Token refresh happens transparently before each API call. For long migration jobs, refresh is called per-batch, not just at start.

**[Risk] Rate limiting by cloud providers** → Mitigation: Migration job uses exponential backoff. Normal usage (single user) is well within rate limits.

**[Risk] Network outage on Raspberry Pi** → Mitigation: v1 fails immediately with clear error. Backup files are retained locally if upload fails (existing behavior). Future: local queue for offline resilience.

**[Risk] OAuth client registration required per provider** → Mitigation: Document setup clearly per provider. Users must create OAuth apps in Dropbox/Google/Microsoft developer consoles. This is a one-time setup. Open question: should we ship pre-registered OAuth clients?

**[Risk] Large file migration timeout** → Mitigation: Migration job processes files one-by-one with progress tracking. Can be paused/resumed. Failed items are skipped and logged for retry.

**[Risk] Breaking change for existing `BACKUP_STORAGE_TYPE` users** → Mitigation: Legacy ENV vars continue working as fallback when no `StorageSetting` exists. Deprecation notice in logs + docs.

**[Trade-off] Single provider for files + backups** → Users cannot store files on Dropbox and backups on S3. Simplifies UX and config. If needed later, `StorageSetting` could support per-namespace provider override.

**[Trade-off] No local caching** → Files served directly from cloud provider. Adds latency on first access. ActiveStorage's built-in redirect-to-signed-URL pattern mitigates this for downloads. Future: local LRU cache layer.

## Migration Plan

1. **Deploy Phase 1** (StorageAdapter + Settings UI): No breaking changes. Default remains local disk. Old BackupStorage still works.
2. **Deploy Phase 2** (S3): Existing S3 backup users can migrate to new unified config via Settings UI, or continue using ENV vars.
3. **Deploy Phases 3-6** (OAuth providers): Each provider is independent. Deploy incrementally.
4. **Future deprecation**: Remove `BackupStorage::*` module and legacy ENV vars after transition period.

**Rollback:** If unified adapter fails, revert to previous code. `BackupStorage::*` module is preserved during transition. Settings table can be dropped via migration rollback.

## Open Questions

1. Should we ship pre-registered OAuth client IDs for Dropbox/Google/OneDrive, or require each user to register their own app?
2. Should we support WebDAV/Nextcloud as a future provider? (common in self-hosted community)
3. Should migration be mandatory or optional when switching providers? (files on old provider become inaccessible if not migrated)
4. Local cache for recently accessed cloud files — worth the complexity for v1?
