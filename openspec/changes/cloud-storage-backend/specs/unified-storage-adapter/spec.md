## ADDED Requirements

### Requirement: Unified storage adapter interface

The system SHALL provide a `StorageAdapter::Base` abstract class with methods: `upload(file_path, key, namespace:)`, `download(key, namespace:)`, `delete(key, namespace:)`, `list(namespace:)`, `url(key, namespace:, expires_in:)`, and `test_connection()`.

#### Scenario: Upload file with namespace

- **WHEN** `StorageAdapter.resolve.upload("/tmp/file.jpg", "abc123.jpg", namespace: :files)` is called
- **THEN** the adapter SHALL store the file under the `files/` namespace and return the storage path as a String

#### Scenario: Upload backup with namespace

- **WHEN** `StorageAdapter.resolve.upload("/tmp/backup.sql.gz", "backup_20250727.sql.gz", namespace: :backups)` is called
- **THEN** the adapter SHALL store the file under the `backups/` namespace and return the storage path as a String

#### Scenario: Download file by key

- **WHEN** `StorageAdapter.resolve.download("abc123.jpg", namespace: :files)` is called for an existing file
- **THEN** the adapter SHALL return a Tempfile containing the file contents

#### Scenario: Delete file by key

- **WHEN** `StorageAdapter.resolve.delete("abc123.jpg", namespace: :files)` is called
- **THEN** the adapter SHALL remove the file from storage

#### Scenario: List files in namespace

- **WHEN** `StorageAdapter.resolve.list(namespace: :backups)` is called
- **THEN** the adapter SHALL return an Array of String keys for all files in the `backups/` namespace

#### Scenario: Generate URL for file

- **WHEN** `StorageAdapter.resolve.url("abc123.jpg", namespace: :files, expires_in: 1.hour)` is called
- **THEN** the adapter SHALL return a URL String for accessing the file (signed URL for cloud providers, local path for disk)

### Requirement: Storage adapter factory resolution

The system SHALL provide a `StorageAdapter.resolve` factory method that reads the active `StorageSetting` from the database and returns the corresponding provider adapter instance.

#### Scenario: No StorageSetting exists

- **WHEN** no `StorageSetting` record exists in the database
- **THEN** `StorageAdapter.resolve` SHALL return a `StorageAdapter::Local` instance

#### Scenario: Active StorageSetting with provider

- **WHEN** a `StorageSetting` record exists with `provider: "dropbox"` and valid config
- **THEN** `StorageAdapter.resolve` SHALL return a `StorageAdapter::Dropbox` instance configured with the stored credentials

#### Scenario: Legacy ENV fallback

- **WHEN** no `StorageSetting` exists but `BACKUP_STORAGE_TYPE=s3` ENV var is set
- **THEN** `StorageAdapter.resolve` SHALL return a `StorageAdapter::S3` instance configured from legacy ENV vars (`BACKUP_S3_BUCKET`, `BACKUP_S3_ACCESS_KEY`, etc.)

### Requirement: Local storage adapter

The system SHALL provide a `StorageAdapter::Local` implementation that stores files on the local filesystem.

#### Scenario: Upload to local filesystem

- **WHEN** a file is uploaded with `namespace: :files`
- **THEN** the adapter SHALL copy the file to `storage/files/<key>` (or configured base path)

#### Scenario: Namespace as subdirectory

- **WHEN** files are uploaded with different namespaces (`:files` and `:backups`)
- **THEN** the adapter SHALL store them in separate subdirectories (`storage/files/` and `storage/backups/`)

#### Scenario: List only returns files in namespace

- **WHEN** `list(namespace: :backups)` is called and both `files/` and `backups/` directories contain files
- **THEN** the adapter SHALL return only keys from the `backups/` directory
