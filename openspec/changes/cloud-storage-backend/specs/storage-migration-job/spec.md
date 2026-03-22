## ADDED Requirements

### Requirement: Storage migration job

The system SHALL provide a `StorageMigrationJob` that copies all existing files and backups from the old storage provider to the new one.

#### Scenario: Migrate ActiveStorage blobs

- **WHEN** the migration job runs after switching from Local to Google Drive
- **THEN** the job SHALL iterate all `ActiveStorage::Blob` records, download each from the old service, and upload to the new service under `namespace: :files`

#### Scenario: Migrate backup records

- **WHEN** the migration job runs after switching providers
- **THEN** the job SHALL iterate all `BackupRecord` entries with `storage_path`, download each backup file from the old service, and upload to the new service under `namespace: :backups`

#### Scenario: Progress tracking

- **WHEN** the migration job is running
- **THEN** the system SHALL track total_items, completed_items, failed_items, and status in a `storage_migrations` table

#### Scenario: Partial failure

- **WHEN** some files fail to copy during migration
- **THEN** the job SHALL log the failures, skip the failed items, and continue with remaining files. Failed items SHALL be marked for retry.

#### Scenario: Resume after interruption

- **WHEN** the migration job is interrupted (server restart, error)
- **THEN** the job SHALL resume from where it left off based on the tracked progress (skip already-migrated items)

### Requirement: Migration UI

The system SHALL display migration progress on the storage settings page.

#### Scenario: No migration in progress

- **WHEN** the user views storage settings and no migration is active
- **THEN** the system SHALL show a "Migrate files" button if there are files on the old provider

#### Scenario: Migration in progress

- **WHEN** a migration job is running
- **THEN** the system SHALL display a progress bar showing completed/total items and elapsed time

#### Scenario: Migration complete

- **WHEN** the migration job finishes successfully
- **THEN** the system SHALL display "Migration complete: N files transferred" with the completion timestamp
