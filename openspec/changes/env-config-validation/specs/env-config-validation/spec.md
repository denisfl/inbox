## ADDED Requirements

### Requirement: Boot-time validation

The application SHALL validate all required environment variables during initialization and fail with a clear error message if any are missing.

#### Scenario: All required variables present

- **WHEN** all required environment variables are set
- **THEN** the application SHALL boot successfully

#### Scenario: Missing required variable

- **WHEN** a required environment variable is missing
- **THEN** the application SHALL raise an error listing all missing variables and refuse to start

#### Scenario: Missing optional variable uses default

- **WHEN** an optional environment variable is not set
- **THEN** the application SHALL use the documented default value

### Requirement: Type coercion

The `AppConfig` module SHALL coerce environment variable values to their expected types.

#### Scenario: Integer coercion

- **GIVEN** `SLOW_OPERATION_THRESHOLD=10`
- **THEN** `AppConfig.slow_operation_threshold` SHALL return `10` as Integer

#### Scenario: Boolean coercion

- **GIVEN** `BACKUP_ENABLED=true`
- **THEN** `AppConfig.backup_enabled?` SHALL return `true` as Boolean

#### Scenario: Invalid type

- **WHEN** a variable value cannot be coerced to its expected type
- **THEN** the application SHALL raise an error naming the variable and expected type

### Requirement: Centralized access

All application code SHALL read configuration through `AppConfig` methods instead of raw `ENV[]` access.

#### Scenario: Config access

- **WHEN** a service needs `TRANSCRIBER_URL`
- **THEN** it SHALL call `AppConfig.transcriber_url` instead of `ENV["TRANSCRIBER_URL"]`
