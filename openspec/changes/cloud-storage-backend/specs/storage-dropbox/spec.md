## ADDED Requirements

### Requirement: Dropbox storage adapter

The system SHALL provide a `StorageAdapter::Dropbox` implementation that stores files in the user's Dropbox account via the Dropbox API v2.

#### Scenario: Upload to Dropbox

- **WHEN** `upload(file_path, key, namespace: :files)` is called
- **THEN** the adapter SHALL upload the file to `/Apps/Inbox/files/<key>` in the user's Dropbox

#### Scenario: Download from Dropbox

- **WHEN** `download(key, namespace: :files)` is called for an existing file
- **THEN** the adapter SHALL download the file content and return a Tempfile

#### Scenario: Generate temporary link

- **WHEN** `url(key, namespace: :files, expires_in: 1.hour)` is called
- **THEN** the adapter SHALL return a temporary direct download link via Dropbox API

#### Scenario: Delete from Dropbox

- **WHEN** `delete(key, namespace: :files)` is called
- **THEN** the adapter SHALL delete the file at `/Apps/Inbox/files/<key>`

#### Scenario: Test connection

- **WHEN** `test_connection()` is called with valid OAuth tokens
- **THEN** the adapter SHALL verify the app folder exists (create if needed) and return `{ ok: true }`

### Requirement: Dropbox ActiveStorage service

The system SHALL provide an `ActiveStorage::Service::DropboxService` that delegates to `StorageAdapter::Dropbox`.

#### Scenario: ActiveStorage upload via Dropbox

- **WHEN** ActiveStorage uploads a blob with the Dropbox service configured
- **THEN** the service SHALL delegate to `StorageAdapter::Dropbox.upload` with `namespace: :files`

#### Scenario: ActiveStorage URL generation

- **WHEN** ActiveStorage generates a URL for a blob stored in Dropbox
- **THEN** the service SHALL return a temporary Dropbox download link
