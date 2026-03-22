## MODIFIED Requirements

### Requirement: Dynamic ActiveStorage service configuration

The system SHALL dynamically configure ActiveStorage to use the provider selected in `StorageSetting`.

#### Scenario: Cloud provider active

- **WHEN** a `StorageSetting` with `provider: "dropbox"` is active
- **THEN** `ActiveStorage::Blob.service` SHALL use `ActiveStorage::Service::UnifiedStorageService` which delegates to `StorageAdapter::Dropbox`

#### Scenario: Local provider active

- **WHEN** no `StorageSetting` exists or `provider: "local"` is configured
- **THEN** `ActiveStorage::Blob.service` SHALL use the default `Disk` service from `config/storage.yml`

#### Scenario: Provider switch without restart

- **WHEN** the user changes the storage provider in settings
- **THEN** new file uploads SHALL immediately use the new provider without requiring an application restart
