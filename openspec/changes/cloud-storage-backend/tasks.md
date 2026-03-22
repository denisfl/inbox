---
id: cloud-storage-backend
artifact: tasks
updated: 2025-07-27
---

## Tasks

### Phase 1: Unified Storage Adapter + Settings infrastructure

- [x] **T1.1** Create `StorageAdapter::Base` interface with methods: `upload(file_path, key, namespace:)`, `download(key, namespace:)`, `delete(key, namespace:)`, `list(namespace:)`, `url(key, namespace:, expires_in:)`, `test_connection()`
- [x] **T1.2** Create `StorageAdapter::Local` implementation (filesystem, default). Supports `namespace:` parameter as subdirectory
- [x] **T1.3** Create `StorageSetting` model (provider, config_encrypted, active) with single-row pattern (only one active config)
- [x] **T1.4** Create `StorageAdapter.resolve()` factory: reads `StorageSetting` from DB, falls back to `Local` if no setting exists
- [x] **T1.5** Refactor `BackupService` to use `StorageAdapter.resolve.upload(..., namespace: :backups)` instead of `BackupStorage.resolve`
- [x] **T1.6** Deprecate `BackupStorage::Base/Local/S3` — keep as thin wrappers delegating to `StorageAdapter` for backward compatibility during transition
- [x] **T1.7** Add `/settings/storage` route and `Settings::StorageController` (index, update, test_connection)
- [x] **T1.8** Build settings UI: provider selector, conditional credential fields per provider, test connection button, save button
- [x] **T1.9** Add settings link to app navigation / sidebar
- [x] **T1.10** Write model specs for `StorageSetting` and unit specs for `StorageAdapter::Local`
- [x] **T1.11** Write request specs for Settings::StorageController CRUD and test_connection

### Phase 2: S3 / S3-compatible backend

- [x] **T2.1** Create `StorageAdapter::S3` implementation using `aws-sdk-s3` gem (already in Gemfile)
- [x] **T2.2** Settings form fields for S3: access_key_id, secret_access_key, region, bucket, endpoint (for S3-compatible)
- [x] **T2.3** Implement `ActiveStorage::Service::UnifiedStorageService` — custom ActiveStorage service that delegates to `StorageAdapter.resolve(namespace: :files)`
- [x] **T2.4** Dynamic ActiveStorage config: update `config/storage.yml` to use `UnifiedStorageService` when cloud provider is configured
- [x] **T2.5** Test connection action for S3: attempt PutObject + GetObject + DeleteObject on a test key
- [x] **T2.6** Write unit specs for `StorageAdapter::S3` and request specs for S3 settings

### Phase 3: OAuth Manager (shared infrastructure)

- [x] **T3.1** Create `OAuthManager` service: `authorize_url(provider)`, `handle_callback(provider, code)`, `refresh_token(provider, refresh_token)`, `revoke(provider, token)`
- [x] **T3.2** Provider-specific OAuth config (client_id, client_secret, scopes, endpoints) loaded from ENV or Rails encrypted credentials
- [x] **T3.3** OAuth routes: `GET /settings/storage/oauth/:provider/authorize`, `GET /settings/storage/oauth/:provider/callback`
- [x] **T3.4** Token storage: encrypted in `StorageSetting.config_encrypted` (refresh_token, access_token, expires_at)
- [x] **T3.5** Automatic token refresh: check expiry before API calls, refresh if needed
- [x] **T3.6** Write request specs for OAuth authorize and callback flows

### Phase 4: Dropbox backend

- [x] **T4.1** Add `dropbox_api` gem
- [x] **T4.2** Create `StorageAdapter::Dropbox` implementation using Dropbox API v2
- [x] **T4.3** Implement `ActiveStorage::Service::DropboxService` delegating to `StorageAdapter::Dropbox`
- [x] **T4.4** OAuth 2.0 flow via `OAuthManager`: authorize → Dropbox consent → callback → store refresh token
- [x] **T4.5** Test connection action: upload/download/delete test file
- [x] **T4.6** Write unit specs for `StorageAdapter::Dropbox` and integration specs for OAuth flow

### Phase 5: Google Drive backend

- [x] **T5.1** Add `google-apis-drive_v3` gem
- [x] **T5.2** Create `StorageAdapter::GoogleDrive` implementation using Google Drive API v3 (files stored in app-specific folder)
- [x] **T5.3** Implement `ActiveStorage::Service::GoogleDriveService` delegating to `StorageAdapter::GoogleDrive`
- [x] **T5.4** OAuth 2.0 flow via `OAuthManager`: authorize → Google consent → callback → store refresh token
- [x] **T5.5** Create app folder in Drive on first connection (`Inbox/files/`, `Inbox/backups/`)
- [x] **T5.6** Test connection action
- [x] **T5.7** Write specs

### Phase 6: OneDrive backend

- [x] **T6.1** Implement `StorageAdapter::OneDrive` using Microsoft Graph API (`/me/drive/items/` endpoints)
- [x] **T6.2** Implement `ActiveStorage::Service::OneDriveService` delegating to `StorageAdapter::OneDrive`
- [x] **T6.3** OAuth 2.0 flow via `OAuthManager`: authorize → Microsoft consent → callback → store refresh token
- [x] **T6.4** Create app folder in OneDrive on first connection (`Apps/Inbox/files/`, `Apps/Inbox/backups/`)
- [x] **T6.5** Test connection action
- [x] **T6.6** Write specs
- [x] **T6.7** Note: No extra gem needed — use `httpx` or `Net::HTTP` for Microsoft Graph API calls

### Phase 7: File and backup migration

- [x] **T7.1** Create `StorageMigrationJob` — iterates all `ActiveStorage::Blob` records + `BackupRecord` entries, copies from old service to new
- [x] **T7.2** Progress tracking: dedicated `storage_migrations` table (total_items, completed_items, failed_items, status, started_at, completed_at)
- [x] **T7.3** Settings UI: show migration progress bar, start/cancel migration button
- [x] **T7.4** Handle partial migration: blobs/backups that fail to copy are logged, can be retried
- [x] **T7.5** Reverse migration: if user switches back to local, copy files back

### Phase 8: Health check and monitoring

- [x] **T8.1** Add recurring health check job: verify cloud storage is reachable (configurable interval)
- [x] **T8.2** If health check fails, log warning and update storage status
- [x] **T8.3** Display storage health status on settings page (connected/disconnected, last check time, storage used)
- [x] **T8.4** Integrate storage status into existing `/api/health` endpoint

### Phase 9: Documentation and deployment

- [x] **T9.1** Update README with cloud storage setup instructions per provider
- [x] **T9.2** Add ENV variable documentation: OAuth client IDs/secrets for each provider
- [x] **T9.3** Update `docker-compose.yml` with storage-related ENV examples
- [x] **T9.4** Deprecation notice for `BACKUP_STORAGE_TYPE`, `BACKUP_S3_*` ENV vars
- [x] **T9.5** End-to-end test: configure S3-compatible storage (MinIO in Docker), upload file + backup, verify stored in MinIO
