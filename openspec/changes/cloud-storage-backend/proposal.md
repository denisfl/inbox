---
id: cloud-storage-backend
title: Unified Cloud Storage (Dropbox / Google Drive / OneDrive / S3)
status: proposed
created: 2025-07-26
updated: 2025-07-27
---

## Problem

All files (audio recordings, images, PDFs, attachments) are stored on-device via ActiveStorage's Disk service. On Raspberry Pi with a limited SD card / USB drive, storage fills up quickly -- especially with audio files (a 10-minute voice note is ~5-10 MB WAV after conversion). There is no off-device backup for attachments; if the drive fails, all files are lost.

Database backups (SQLite dumps) use a separate `BackupStorage` adapter (Local / S3), configured independently via ENV variables. This means the user manages two different storage configurations with no shared interface.

Users who already pay for cloud storage (Dropbox, Google Drive, OneDrive, S3) cannot leverage that space for their Inbox files or backups.

## Solution

Unify file storage (ActiveStorage) and backup storage under a single storage provider configuration. When a user configures Google Drive, **both** document files and database backups are stored there. The local disk remains available as a fallback / default.

### Unified Storage Adapter Pattern

A single `StorageAdapter` interface with implementations for each provider. Both ActiveStorage (files) and BackupStorage (database dumps) use the same configured provider.

```
StorageAdapter (interface)
├── upload(file_path, key, namespace:)
├── download(key, namespace:)
├── delete(key, namespace:)
├── list(namespace:)
├── url(key, namespace:, expires_in:)
└── test_connection()

Implementations:
├── StorageAdapter::Local       -- filesystem (default)
├── StorageAdapter::S3          -- AWS S3 / S3-compatible
├── StorageAdapter::Dropbox     -- Dropbox API v2 + OAuth 2.0
├── StorageAdapter::GoogleDrive -- Google Drive API + OAuth 2.0
└── StorageAdapter::OneDrive    -- Microsoft Graph API + OAuth 2.0
```

The `namespace:` parameter separates file types (e.g., `files/`, `backups/`) within the same provider.

### Supported Providers (priority order)

1. **Dropbox** -- most personal users have it; simple OAuth + API
2. **Google Drive** -- common; Google Drive API for personal accounts
3. **OneDrive** -- common on Windows/Microsoft ecosystem; Microsoft Graph API
4. **Amazon S3** / **S3-compatible** (MinIO, Backblaze B2, Cloudflare R2) -- for power users
5. **Local disk** -- current default, always available

### User Experience

1. Admin opens Settings page (new route: `/settings/storage`)
2. Selects provider from dropdown (Local / Dropbox / Google Drive / OneDrive / S3)
3. Authenticates via OAuth flow (Dropbox, Google, OneDrive) or enters credentials (S3)
4. Clicks "Test Connection" -- app verifies read/write access
5. Clicks "Save" -- both file storage and backup storage switch to the new backend
6. Existing local files and backups optionally migrated to cloud (background job)

## Capabilities

### New Capabilities

- `unified-storage-adapter`: Single `StorageAdapter` interface used by both ActiveStorage and BackupStorage, replacing the current separate `BackupStorage::Base` pattern
- `storage-settings-ui`: Settings page for configuring cloud storage provider, credentials, and connection test
- `storage-settings-model`: `StorageSetting` model with provider config, encrypted credentials, and single-row active pattern
- `storage-dropbox`: Dropbox integration via OAuth 2.0 + Dropbox API v2. Custom ActiveStorage service wrapping the Dropbox SDK
- `storage-google-drive`: Google Drive integration via OAuth 2.0 + Google Drive API v3. Custom ActiveStorage service for personal Drive storage
- `storage-onedrive`: OneDrive integration via OAuth 2.0 + Microsoft Graph API. Custom ActiveStorage service
- `storage-s3`: S3 / S3-compatible storage. Uses Rails built-in S3 service with custom endpoint support
- `storage-oauth-manager`: Reusable OAuth 2.0 flow handling -- authorize, callback, token refresh -- shared across Dropbox, Google, and OneDrive
- `storage-migration-job`: Background job to migrate existing files and backups from one backend to another
- `storage-health-check`: Periodic check that cloud storage is reachable; log warnings if unavailable

### Modified Capabilities

- `backup-storage`: Replace current `BackupStorage::Base/Local/S3` with calls to unified `StorageAdapter` (namespace: `backups`)
- `active-storage-config`: `config/storage.yml` dynamically selects the configured service
- `docker-compose`: Add environment variables for storage credentials
- `settings-route`: New `/settings` namespace for app configuration

## Design Decisions

### Why a unified adapter?

Currently, BackupStorage and ActiveStorage are completely independent systems:

- BackupStorage: custom adapter (Local / S3) configured via ENV vars
- ActiveStorage: Rails built-in (Disk only, in practice)

This means configuring storage twice and potentially storing files in two different places. A unified adapter ensures: one config, one provider, all data in one place. BackupService calls `StorageAdapter.resolve.upload(dump_path, key, namespace: :backups)` instead of `BackupStorage.resolve.upload(...)`.

### Why Google Drive API instead of GCS?

The target user is a single person with a personal Google account, not a GCP project. Google Drive API v3 provides direct access to the user's Drive storage via OAuth 2.0, while GCS requires a GCP project + service account. Using Drive API is more accessible for the typical Inbox user.

### Why OneDrive?

Many users in the Microsoft ecosystem have OneDrive storage included with Microsoft 365. The Microsoft Graph API provides clean OAuth 2.0 + file operations. Adding it as a 4th provider covers the three major personal cloud storage platforms.

### ActiveStorage integration approach

For providers that Rails ActiveStorage doesn't natively support (Dropbox, Google Drive, OneDrive), we create custom `ActiveStorage::Service::*` subclasses that delegate to our `StorageAdapter` implementations. This keeps all file upload/download/url code in the app unchanged.

### OAuth vs API keys

Dropbox, Google Drive, and OneDrive use OAuth 2.0 for authentication. The app stores refresh tokens encrypted in the database (`StorageSetting.config_encrypted`). For S3, static access keys are used (standard practice). A shared `OAuthManager` handles the authorize → callback → token refresh flow for all three OAuth providers.

### File and backup migration

When switching backends, existing files AND backups need to be copied. A background job iterates:

1. All `ActiveStorage::Blob` records (document files)
2. All `BackupRecord` entries (database dumps)

Progress is tracked and shown on the settings page.

### Offline resilience

If the cloud backend is unreachable (network outage, RPi offline), uploads fail. Options:

- **A) Queue locally, sync later** -- complex but resilient (like Syncthing)
- **B) Fail immediately, show error** -- simple, user retries when online

Recommendation: **Option B** for v1 (simple). Add local queue (Option A) as a future enhancement. For backups specifically: retain the local dump file if upload fails (current behavior).

## Non-Goals

- Bidirectional sync (Inbox is the source of truth, not the cloud folder)
- Browsing cloud storage contents from within Inbox
- Multi-cloud mirroring (ActiveStorage Mirror service exists but adds complexity)
- End-to-end encryption of cloud-stored files (rely on provider encryption)
- iCloud integration (no public API for file storage)
- Separate provider config for files vs backups (unified by design)

## Impact

- **Database**: 1 new table `storage_settings` (provider, config_encrypted, active)
- **Gems**: `dropbox_api`, `google-apis-drive_v3`, `microsoft_graph` (or raw HTTP to Graph API), `aws-sdk-s3` (already present)
- **Refactoring**: `BackupStorage::Base/Local/S3` → replaced by `StorageAdapter` with `namespace: :backups`
- **Docker**: New ENV vars for OAuth client IDs/secrets per provider
- **Security**: OAuth tokens and S3 keys stored encrypted in database; client secrets via ENV or Rails encrypted credentials
- **Performance**: Cloud storage adds latency to file uploads/downloads vs local disk. Mitigated by ActiveStorage's redirect-based serving (302 to signed cloud URL)
- **Backward compatibility**: Default remains local disk. No changes for users who don't configure cloud storage. Existing `BACKUP_STORAGE_TYPE` ENV var deprecated in favor of unified settings

## Open Questions

1. Should we support Nextcloud / WebDAV as a provider? (common in self-hosted community)
2. Should file migration be mandatory or optional when switching providers?
3. Should we cache recently accessed files locally for faster serving?
4. Should OAuth client IDs be hardcoded (single-instance app) or user-configurable?
