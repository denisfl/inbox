## ADDED Requirements

### Requirement: StorageSetting model with single-row pattern

The system SHALL provide a `StorageSetting` model with fields: `provider` (String, not null, default "local"), `config_encrypted` (Text, encrypted), `active` (Boolean, not null, default true), `status` (String, default "unchecked"), `last_checked_at` (DateTime).

#### Scenario: Only one active setting

- **WHEN** a new `StorageSetting` is saved with `active: true`
- **THEN** the system SHALL ensure only one record exists with `active: true` (previous active record is updated or replaced)

#### Scenario: Default provider

- **WHEN** no `StorageSetting` record exists
- **THEN** the system SHALL behave as if `provider: "local"` is configured

#### Scenario: Encrypted config storage

- **WHEN** OAuth tokens or S3 credentials are stored in `config_encrypted`
- **THEN** the system SHALL use Rails ActiveRecord encryption to encrypt the JSON blob at rest

### Requirement: Valid provider values

The system SHALL validate that `provider` is one of: `local`, `s3`, `dropbox`, `google_drive`, `onedrive`.

#### Scenario: Invalid provider

- **WHEN** a `StorageSetting` is created with `provider: "ftp"`
- **THEN** the system SHALL reject the record with a validation error

#### Scenario: Valid provider

- **WHEN** a `StorageSetting` is created with `provider: "google_drive"`
- **THEN** the system SHALL accept and save the record

### Requirement: Config accessor methods

The system SHALL provide typed accessor methods for provider-specific config fields (e.g., `access_key_id`, `refresh_token`, `bucket`) that read from the encrypted JSON config.

#### Scenario: Read S3 config

- **WHEN** `StorageSetting` has `provider: "s3"` and `config` contains `{ "bucket": "my-bucket", "region": "us-east-1" }`
- **THEN** `setting.config_data["bucket"]` SHALL return `"my-bucket"`

#### Scenario: Update config

- **WHEN** `setting.config_data = { "refresh_token": "new_token" }` is assigned and saved
- **THEN** the encrypted column SHALL contain the updated JSON
