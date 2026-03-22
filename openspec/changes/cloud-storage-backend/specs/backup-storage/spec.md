## MODIFIED Requirements

### Requirement: External storage upload

The system SHALL upload compressed backup files to the unified storage adapter instead of the separate BackupStorage module.

#### Scenario: Unified adapter for backups

- **WHEN** the backup job runs
- **THEN** `BackupService` SHALL call `StorageAdapter.resolve.upload(temp_path, key, namespace: :backups)` instead of `BackupStorage.resolve.upload(temp_path, key)`

#### Scenario: Cloud provider configured

- **WHEN** the user has configured Google Drive as the storage provider
- **THEN** database backups SHALL be uploaded to the `Inbox/backups/` folder in Google Drive

#### Scenario: Local provider configured

- **WHEN** the storage provider is set to "local" (default)
- **THEN** database backups SHALL be stored in `storage/backups/` on the local filesystem (same behavior as current `BackupStorage::Local`)

#### Scenario: Legacy ENV vars backward compatibility

- **WHEN** `BACKUP_STORAGE_TYPE=s3` ENV var is set and no `StorageSetting` exists
- **THEN** the system SHALL continue to use S3 for backups via `StorageAdapter::S3` configured from legacy ENV vars

### Requirement: Backup retention uses unified adapter

The system SHALL use the unified storage adapter for deleting old backup files during retention cleanup.

#### Scenario: Delete old backups from cloud

- **WHEN** backup retention cleanup runs and backups are stored on a cloud provider
- **THEN** the system SHALL call `StorageAdapter.resolve.delete(key, namespace: :backups)` for each expired backup
