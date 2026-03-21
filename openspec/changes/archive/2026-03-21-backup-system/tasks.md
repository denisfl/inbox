## 1. Database & Model

- [x] 1.1 Create migration for `backup_records` table (columns: `status`, `started_at`, `completed_at`, `size_bytes`, `storage_path`, `storage_type`, `error_message`)
- [x] 1.2 Create `BackupRecord` model with validations and scopes (`latest`, `successful`, `failed`)

## 2. Storage Backends

- [x] 2.1 Create `BackupStorage::Base` abstract class with `#upload(file_path, key)`, `#delete(key)`, `#list` interface
- [x] 2.2 Implement `BackupStorage::Local` — copies backup to configured local path
- [x] 2.3 Implement `BackupStorage::S3` — uploads to S3-compatible bucket using `aws-sdk-s3`
- [x] 2.4 Create `BackupStorage.resolve` factory method that reads `BACKUP_STORAGE_TYPE` env and returns the appropriate backend

## 3. Backup Service

- [x] 3.1 Create `BackupService` that orchestrates: dump SQLite → compress gzip → upload via storage backend → record metadata → cleanup temp file
- [x] 3.2 Implement SQLite dump execution (`sqlite3 <db_path> .dump | gzip > <temp_path>`)
- [x] 3.3 Implement retention cleanup: delete backups and `BackupRecord` entries older than `BACKUP_RETENTION_DAYS` (default 30)
- [x] 3.4 Handle failure cases: log errors, record failure in `BackupRecord`, retain local file on upload failure

## 4. Background Job

- [x] 4.1 Create `BackupJob` that calls `BackupService`
- [x] 4.2 Add recurring task to `config/recurring.yml`: daily at 03:00
- [x] 4.3 Configure `retry_on` for transient failures (network errors) and `discard_on` for permanent failures

## 5. Health Check Endpoint

- [x] 5.1 Add `GET /api/health` endpoint (or extend existing) with backup status from `BackupRecord.latest`
- [x] 5.2 Return backup status object: `{status, last_backup_at, size_bytes}` or `{status: "failed", last_error}` or `{status: "never_run"}`

## 6. Configuration

- [x] 6.1 Add ENV variables to `.env.example`: `BACKUP_STORAGE_TYPE`, `BACKUP_S3_BUCKET`, `BACKUP_S3_ACCESS_KEY`, `BACKUP_S3_SECRET_KEY`, `BACKUP_S3_REGION`, `BACKUP_S3_ENDPOINT`, `BACKUP_LOCAL_PATH`, `BACKUP_RETENTION_DAYS`
- [x] 6.2 Add `aws-sdk-s3` gem to Gemfile (optional group or lazy-loaded)

## 7. Documentation

- [x] 7.1 Create `docs/recovery.md` with step-by-step restore instructions (locate backup, decompress, restore, verify)
- [x] 7.2 Document backup configuration in README or `.env.example` comments

## 8. Tests

- [x] 8.1 Unit tests for `BackupService` (mock storage backend, verify dump/compress/upload/cleanup flow)
- [x] 8.2 Unit tests for `BackupStorage::Local` (verify file copy and deletion)
- [x] 8.3 Unit tests for `BackupRecord` model (scopes, validations)
- [x] 8.4 Request spec for `GET /api/health` backup status (ok, failed, never_run scenarios)
- [x] 8.5 Unit test for retention cleanup (verify old records and files are deleted)
