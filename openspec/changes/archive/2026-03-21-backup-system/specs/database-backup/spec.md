## ADDED Requirements

### Requirement: Automated daily database backup
The system SHALL automatically create a full SQLite database dump every day at 03:00 server time via a SolidQueue recurring job.

#### Scenario: Successful daily backup
- **WHEN** the scheduled time 03:00 arrives
- **THEN** the system SHALL execute `sqlite3 .dump` on the production database, compress the output with gzip, and store the file as `backup_YYYYMMDD.sql.gz`

#### Scenario: Database is locked during backup
- **WHEN** the database has active write connections during backup
- **THEN** the system SHALL use SQLite's `.dump` command which reads a consistent snapshot, producing a valid backup without interrupting writes

### Requirement: External storage upload
The system SHALL upload compressed backup files to a configurable external storage backend.

#### Scenario: S3-compatible storage configured
- **WHEN** `BACKUP_STORAGE_TYPE` is set to `s3` and `BACKUP_S3_BUCKET`, `BACKUP_S3_ACCESS_KEY`, `BACKUP_S3_SECRET_KEY` are configured
- **THEN** the system SHALL upload the backup file to the specified S3 bucket with path `backups/backup_YYYYMMDD.sql.gz`

#### Scenario: Local path storage configured
- **WHEN** `BACKUP_STORAGE_TYPE` is set to `local` and `BACKUP_LOCAL_PATH` is configured
- **THEN** the system SHALL copy the backup file to the specified local directory

#### Scenario: No storage configured
- **WHEN** backup storage environment variables are not set
- **THEN** the system SHALL log a warning and store the backup in `storage/backups/` within the application directory

### Requirement: Backup retention policy
The system SHALL automatically delete backup files older than a configurable retention period.

#### Scenario: Default retention period
- **WHEN** `BACKUP_RETENTION_DAYS` is not set
- **THEN** the system SHALL delete backups older than 30 days

#### Scenario: Custom retention period
- **WHEN** `BACKUP_RETENTION_DAYS` is set to a positive integer
- **THEN** the system SHALL delete backups older than that number of days

### Requirement: Backup failure handling
The system SHALL handle backup failures gracefully and provide actionable error information.

#### Scenario: SQLite dump fails
- **WHEN** the `sqlite3 .dump` command fails (non-zero exit code)
- **THEN** the system SHALL log the error with full command output and record the failure timestamp

#### Scenario: Storage upload fails
- **WHEN** the backup file is created but upload to external storage fails
- **THEN** the system SHALL retain the local backup file, log the upload error, and record the failure

### Requirement: Recovery documentation
The system SHALL include documentation for recovering from a backup.

#### Scenario: User needs to restore from backup
- **WHEN** a user reads `docs/recovery.md`
- **THEN** the document SHALL contain step-by-step instructions for: locating the latest backup, decompressing, restoring to a fresh SQLite database, and verifying data integrity
