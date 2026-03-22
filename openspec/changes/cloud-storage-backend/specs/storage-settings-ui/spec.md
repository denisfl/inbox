## ADDED Requirements

### Requirement: Storage settings page

The system SHALL provide a settings page at `/settings/storage` where the user can view and configure the active storage provider.

#### Scenario: View current settings

- **WHEN** the user navigates to `/settings/storage`
- **THEN** the system SHALL display the currently configured provider, connection status, and provider-specific fields

#### Scenario: No settings configured

- **WHEN** the user navigates to `/settings/storage` and no `StorageSetting` exists
- **THEN** the system SHALL show "Local disk" as the default provider with an option to switch

### Requirement: Provider selector

The system SHALL display a provider selector with options: Local, S3/S3-compatible, Dropbox, Google Drive, OneDrive.

#### Scenario: Select S3 provider

- **WHEN** the user selects "S3 / S3-compatible" from the provider selector
- **THEN** the system SHALL show credential fields: Access Key ID, Secret Access Key, Region, Bucket Name, Endpoint (optional)

#### Scenario: Select OAuth provider (Dropbox / Google Drive / OneDrive)

- **WHEN** the user selects "Dropbox" from the provider selector
- **THEN** the system SHALL show a "Connect to Dropbox" button instead of credential fields

#### Scenario: Select Local provider

- **WHEN** the user selects "Local disk" from the provider selector
- **THEN** the system SHALL hide all credential fields

### Requirement: Test connection

The system SHALL provide a "Test Connection" action that verifies the configured provider is reachable and has proper access.

#### Scenario: Successful S3 test

- **WHEN** the user clicks "Test Connection" with valid S3 credentials
- **THEN** the system SHALL attempt PutObject + GetObject + DeleteObject on a test key and display "Connection successful"

#### Scenario: Failed test

- **WHEN** the user clicks "Test Connection" with invalid credentials
- **THEN** the system SHALL display an error message describing the failure

#### Scenario: OAuth provider not connected

- **WHEN** the user clicks "Test Connection" for Dropbox but OAuth flow has not been completed
- **THEN** the system SHALL display "Not connected. Please connect to Dropbox first."

### Requirement: Save storage settings

The system SHALL allow the user to save the selected provider and credentials.

#### Scenario: Save S3 settings

- **WHEN** the user fills in S3 credentials and clicks "Save"
- **THEN** the system SHALL create/update the `StorageSetting` record with the encrypted credentials and redirect back with a success message

#### Scenario: Save switches both files and backups

- **WHEN** the user saves a new provider (e.g., Google Drive)
- **THEN** both document file storage (ActiveStorage) and backup storage SHALL use the new provider

### Requirement: Settings navigation link

The system SHALL provide a link to the storage settings page from the app navigation.

#### Scenario: Settings link visible

- **WHEN** the user views any page in the app
- **THEN** a "Settings" or "Storage" link SHALL be accessible from the navigation sidebar or header
