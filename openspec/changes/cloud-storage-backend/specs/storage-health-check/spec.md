## ADDED Requirements

### Requirement: Storage health check job

The system SHALL provide a recurring job that periodically verifies the configured cloud storage provider is reachable.

#### Scenario: Healthy cloud storage

- **WHEN** the health check job runs and the cloud provider responds successfully
- **THEN** the system SHALL update `StorageSetting.status` to `"connected"` and `last_checked_at` to the current time

#### Scenario: Unreachable cloud storage

- **WHEN** the health check job runs and the cloud provider fails to respond
- **THEN** the system SHALL update `StorageSetting.status` to `"error"` and log a warning

#### Scenario: Local storage always healthy

- **WHEN** the health check job runs and the provider is `"local"`
- **THEN** the system SHALL verify the storage directory is writable and update status to `"connected"`

### Requirement: Storage status in health API

The system SHALL include storage provider status in the existing `/api/health` endpoint.

#### Scenario: Storage status in health response

- **WHEN** `GET /api/health` is called
- **THEN** the response SHALL include a `storage` section with `provider`, `status` ("connected", "error", "unchecked"), and `last_checked_at`

### Requirement: Storage status on settings page

The system SHALL display the current storage health status on the `/settings/storage` page.

#### Scenario: Connected status

- **WHEN** the user views storage settings and `StorageSetting.status` is "connected"
- **THEN** the system SHALL display a green status indicator with "Connected" and the last check timestamp

#### Scenario: Error status

- **WHEN** the user views storage settings and `StorageSetting.status` is "error"
- **THEN** the system SHALL display a red status indicator with "Disconnected" and suggest the user check credentials or network
