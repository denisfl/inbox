## ADDED Requirements

### Requirement: Critical failure notification

The system SHALL send a Telegram notification when a critical failure occurs.

#### Scenario: Job failure triggers notification

- **WHEN** a background job fails all retry attempts
- **THEN** the system SHALL send a Telegram message to the configured admin chat with job name, error class, error message, and timestamp

#### Scenario: Integration unavailable

- **WHEN** a health check detects an integration is unavailable
- **THEN** the system SHALL send a Telegram notification with the integration name and failure details

#### Scenario: Notification delivery failure

- **WHEN** the Telegram notification itself fails to send
- **THEN** the system SHALL log the failure at ERROR level and NOT retry the notification (avoid cascade)

### Requirement: Slow operation logging

The system SHALL log operations that exceed a configurable time threshold.

#### Scenario: Slow operation detected

- **WHEN** an external service call takes longer than `SLOW_OPERATION_THRESHOLD` (default 5 seconds)
- **THEN** the system SHALL log a warning with operation name, duration, and context

#### Scenario: Threshold configuration

- **GIVEN** the environment variable `SLOW_OPERATION_THRESHOLD` is set
- **THEN** the system SHALL use that value (in seconds) as the threshold
