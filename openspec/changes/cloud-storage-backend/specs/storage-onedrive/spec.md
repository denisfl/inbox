## ADDED Requirements

### Requirement: OneDrive storage adapter

The system SHALL provide a `StorageAdapter::OneDrive` implementation that stores files in the user's OneDrive via the Microsoft Graph API.

#### Scenario: Upload to OneDrive

- **WHEN** `upload(file_path, key, namespace: :files)` is called
- **THEN** the adapter SHALL upload the file to `Apps/Inbox/files/<key>` in the user's OneDrive

#### Scenario: Download from OneDrive

- **WHEN** `download(key, namespace: :files)` is called for an existing file
- **THEN** the adapter SHALL download the file content via Graph API and return a Tempfile

#### Scenario: Generate download URL

- **WHEN** `url(key, namespace: :files, expires_in: 1.hour)` is called
- **THEN** the adapter SHALL create a sharing link or use the `@microsoft.graph.downloadUrl` and return it

#### Scenario: Delete from OneDrive

- **WHEN** `delete(key, namespace: :files)` is called
- **THEN** the adapter SHALL delete the item at `Apps/Inbox/files/<key>`

#### Scenario: App folder creation

- **WHEN** `test_connection()` is called and the `Apps/Inbox/` folder does not exist
- **THEN** the adapter SHALL create the folder structure and store the drive_id and folder_id in `StorageSetting.config_encrypted`

#### Scenario: Test connection

- **WHEN** `test_connection()` is called with valid OAuth tokens
- **THEN** the adapter SHALL verify Graph API access and folder existence, returning `{ ok: true }`

### Requirement: OneDrive ActiveStorage service

The system SHALL provide an `ActiveStorage::Service::OneDriveService` that delegates to `StorageAdapter::OneDrive`.

#### Scenario: ActiveStorage upload via OneDrive

- **WHEN** ActiveStorage uploads a blob with the OneDrive service configured
- **THEN** the service SHALL delegate to `StorageAdapter::OneDrive.upload` with `namespace: :files`

### Requirement: OneDrive uses raw HTTP (no external gem)

The system SHALL implement OneDrive support using `Net::HTTP` or an HTTP client already in the project, without adding a dedicated Microsoft Graph gem.

#### Scenario: Graph API calls

- **WHEN** any OneDrive storage operation is performed
- **THEN** the adapter SHALL make direct HTTP requests to `https://graph.microsoft.com/v1.0/` endpoints
