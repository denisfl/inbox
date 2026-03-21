## Why

All data (SQLite database, Active Storage files) lives on a single Raspberry Pi. A hardware failure, SD card corruption, or accidental deletion means total data loss with no recovery path. Automated backup is the highest-priority reliability improvement.

## What Changes

- New `BackupJob` (SolidQueue) running daily at 03:00 that dumps the SQLite database, compresses it, and uploads to configurable external storage
- Automatic retention policy: delete backups older than 30 days
- Backup status exposed via health-check endpoint for monitoring
- Recovery procedure documented in `docs/recovery.md`
- New ENV variables for storage backend configuration (S3-compatible, rsync, or local path)

## Capabilities

### New Capabilities
- `database-backup`: Automated daily SQLite backup with compression, external storage upload, and retention policy
- `backup-health-check`: Backup success/failure status in the health-check endpoint

### Modified Capabilities
<!-- No existing specs are modified -->

## Impact

- **New files**: `app/jobs/backup_job.rb`, `app/services/backup_service.rb`, `docs/recovery.md`
- **Config**: `config/recurring.yml` (add daily backup schedule), `.env.example` (backup storage variables)
- **Dependencies**: No new gems required — `sqlite3` CLI already available in Docker, `aws-sdk-s3` gem only if S3 backend chosen
- **Systems**: Requires configured external storage target (S3, Backblaze B2, rsync destination, or mounted volume)
