## ADDED Requirements

### Requirement: Google Drive storage adapter

The system SHALL provide a `StorageAdapter::GoogleDrive` implementation that stores files in the user's Google Drive via the Google Drive API v3.

#### Scenario: Upload to Google Drive

- **WHEN** `upload(file_path, key, namespace: :files)` is called
- **THEN** the adapter SHALL upload the file to the `Inbox/files/` folder in the user's Google Drive

#### Scenario: Download from Google Drive

- **WHEN** `download(key, namespace: :files)` is called for an existing file
- **THEN** the adapter SHALL download the file content via Drive API and return a Tempfile

#### Scenario: Generate download URL

- **WHEN** `url(key, namespace: :files, expires_in: 1.hour)` is called
- **THEN** the adapter SHALL return a time-limited download URL via Google Drive API

#### Scenario: Delete from Google Drive

- **WHEN** `delete(key, namespace: :files)` is called
- **THEN** the adapter SHALL permanently delete the file from the `Inbox/files/` folder

#### Scenario: App folder creation

- **WHEN** `test_connection()` is called and the `Inbox/` folder does not exist
- **THEN** the adapter SHALL create the `Inbox/` folder with `files/` and `backups/` subfolders and store the folder IDs in `StorageSetting.config_encrypted`

#### Scenario: Test connection

- **WHEN** `test_connection()` is called with valid OAuth tokens
- **THEN** the adapter SHALL verify Drive API access and folder existence, returning `{ ok: true }`

### Requirement: Google Drive ActiveStorage service

The system SHALL provide an `ActiveStorage::Service::GoogleDriveService` that delegates to `StorageAdapter::GoogleDrive`.

#### Scenario: ActiveStorage upload via Google Drive

- **WHEN** ActiveStorage uploads a blob with the Google Drive service configured
- **THEN** the service SHALL delegate to `StorageAdapter::GoogleDrive.upload` with `namespace: :files`
