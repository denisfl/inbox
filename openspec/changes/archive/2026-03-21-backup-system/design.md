## Context

Inbox runs on a Raspberry Pi 5 with SQLite as the single database. All user data (documents, tasks, calendar events, tags, links) is stored in a single SQLite file. Active Storage attachments are stored in `storage/`. There is currently no backup mechanism — hardware failure means total data loss.

SolidQueue is already used for background jobs with recurring task support via `config/recurring.yml`. The Docker setup uses volumes for persistent data.

## Goals / Non-Goals

**Goals:**
- Automated daily backup of the SQLite database with zero manual intervention
- Configurable external storage (S3-compatible or local/mounted path)
- Automatic cleanup of old backups
- Monitoring via health-check endpoint
- Clear recovery documentation

**Non-Goals:**
- Active Storage file backup (phase 2 — can be added to BackupService later)
- Real-time replication or WAL shipping
- Point-in-time recovery (daily granularity is sufficient)
- Multi-database backup (only the primary SQLite DB)

## Decisions

### 1. SQLite `.dump` over file copy
**Choice**: Use `sqlite3 <db> .dump` piped to gzip, not `cp` of the SQLite file.
**Rationale**: `.dump` produces a text SQL file that is safe to create while the database is in use (no locking issues). A raw file copy of an active SQLite database can produce a corrupted backup if writes happen during copy. The dump is also portable across SQLite versions.
**Alternative considered**: `VACUUM INTO` — requires SQLite 3.27+, locks the database briefly, produces a binary file (less portable). Good for large DBs but overkill for our size.

### 2. Storage abstraction with strategy pattern
**Choice**: `BackupStorage::Base` with `BackupStorage::S3` and `BackupStorage::Local` implementations.
**Rationale**: Keeps the backup job simple — it produces a file, then hands off to the storage backend. Adding new backends (rsync, Backblaze B2 native) requires only a new class.
**Alternative considered**: Direct S3 calls in the job — simpler initially but not extensible.

### 3. Metadata in application database
**Choice**: Store backup metadata (timestamp, size, status, storage path) in a `backup_records` table in the application database.
**Rationale**: Health-check endpoint needs to query last backup status. A DB record is simpler and more reliable than parsing filesystem metadata or S3 listings.
**Alternative considered**: Writing metadata to a JSON file — fragile, no query support.

### 4. SolidQueue recurring task
**Choice**: Configure via `config/recurring.yml` with `cron: "0 3 * * *"`.
**Rationale**: SolidQueue recurring tasks are already used in the project. No new dependencies. Built-in retry support.

## Risks / Trade-offs

- **[Risk] Backup of backup metadata** → The `backup_records` table lives in the same DB being backed up. If the DB is lost, we lose backup history too. Mitigation: backup history is informational — actual backups exist on external storage and can be found by listing the storage bucket/directory.
- **[Risk] S3 credentials in environment** → Credentials for external storage in ENV variables. Mitigation: already the pattern used for all integrations (Telegram, Google Calendar). Use Rails credentials for production if preferred.
- **[Risk] Disk space for temporary local backup** → The dump + gzip happens locally before upload. Mitigation: SQLite DB is small (<100MB expected). Cleanup temp file after successful upload.
- **[Trade-off] No Active Storage backup** → Attachments (images, PDFs, audio) are not backed up. These are typically larger than the DB. Separate mechanism needed later (rsync of storage/ directory).

## Migration Plan

1. Create migration for `backup_records` table
2. Add `BackupService` and storage backends
3. Add `BackupJob` with SolidQueue recurring config
4. Add backup status to health-check endpoint (creates endpoint if not existing)
5. Create `docs/recovery.md`
6. Deploy — backup starts automatically next 03:00

**Rollback**: Remove recurring task from `config/recurring.yml`. No data migration needed.

## Open Questions

- Should Active Storage files be included in the same backup job (phase 1) or deferred?
- Is Backblaze B2 preferred over generic S3-compatible, or should we support both via the same S3 interface?
- Should backup failure trigger a Telegram notification (ties into `observability-status-page` change)?
