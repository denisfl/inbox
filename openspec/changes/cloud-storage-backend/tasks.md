---
id: cloud-storage-backend
artifact: tasks
---

## Tasks

### Phase 1: Settings infrastructure

- [ ] **T1.1** Create `StorageSetting` model (provider, config_encrypted, active) with single-row pattern (only one active config)
- [ ] **T1.2** Add `/settings/storage` route and `Settings::StorageController` (index, update, test_connection)
- [ ] **T1.3** Build settings UI: provider selector, credential fields (conditional per provider), test button, save button
- [ ] **T1.4** Add settings link to app navigation / header menu

### Phase 2: S3 / S3-compatible backend

- [ ] **T2.1** Add `aws-sdk-s3` gem (if not already present)
- [ ] **T2.2** Settings form for S3: access_key_id, secret_access_key, region, bucket, endpoint (for S3-compatible)
- [ ] **T2.3** Dynamic ActiveStorage service configuration: read from `StorageSetting` and configure `ActiveStorage::Blob.service` at runtime
- [ ] **T2.4** Test connection action: attempt PutObject + GetObject + DeleteObject on a test key
- [ ] **T2.5** Write request specs for S3 settings CRUD and connection test

### Phase 3: Dropbox backend

- [ ] **T3.1** Add `dropbox_api` gem
- [ ] **T3.2** Implement `ActiveStorage::Service::DropboxService` (upload, download, delete, exist?, url_for_direct_upload)
- [ ] **T3.3** OAuth 2.0 flow: `/settings/storage/dropbox/authorize` -> redirect to Dropbox -> callback with code -> exchange for refresh token
- [ ] **T3.4** Store refresh token in encrypted credentials
- [ ] **T3.5** Token refresh logic (Dropbox refresh tokens are long-lived but access tokens expire in 4h)
- [ ] **T3.6** Test connection action: list root folder or upload test file
- [ ] **T3.7** Write request specs for Dropbox OAuth flow and service operations

### Phase 4: Google Drive / GCS backend

- [ ] **T4.1** Add `google-cloud-storage` gem
- [ ] **T4.2** OAuth 2.0 flow for Google: similar to Dropbox but using Google OAuth endpoints
- [ ] **T4.3** Configure Rails built-in GCS service with obtained credentials
- [ ] **T4.4** Test connection action
- [ ] **T4.5** Write request specs

### Phase 5: File migration

- [ ] **T5.1** Create `StorageMigrationJob` -- iterates all `ActiveStorage::Blob` records, copies from old service to new
- [ ] **T5.2** Progress tracking: use `StorageSetting` or dedicated model to track migration status (total, completed, failed)
- [ ] **T5.3** Settings UI: show migration progress, start/cancel migration button
- [ ] **T5.4** Handle partial migration: blobs that fail to copy are logged, can be retried

### Phase 6: Health check and fallback

- [ ] **T6.1** Add periodic health check (cron or recurring job): verify cloud storage is reachable
- [ ] **T6.2** If health check fails, log warning (no automatic fallback in v1)
- [ ] **T6.3** Display storage health status on settings page

### Phase 7: Documentation and deployment

- [ ] **T7.1** Update README with cloud storage setup instructions
- [ ] **T7.2** Add ENV variable documentation for Docker deployment
- [ ] **T7.3** Update `docker-compose.yml` with storage-related ENV examples
- [ ] **T7.4** End-to-end test: configure S3-compatible storage (MinIO in Docker), upload file, verify stored in MinIO
