## ADDED Requirements

### Requirement: Admin status page access

The system SHALL provide a `/admin/status` page protected by HTTP Basic Auth.

#### Scenario: Authenticated access

- **WHEN** a user visits `/admin/status` and provides valid credentials
- **THEN** the system SHALL display the status dashboard

#### Scenario: Unauthenticated access

- **WHEN** a user visits `/admin/status` without credentials
- **THEN** the system SHALL return HTTP 401 and prompt for authentication

### Requirement: Integration status display

The status page SHALL display the current status of each external integration.

#### Scenario: Viewing integration statuses

- **WHEN** the admin views the status page
- **THEN** the page SHALL show status (ok/unavailable) for: Database, Transcriber, Google Calendar

### Requirement: Job queue display

The status page SHALL display SolidQueue job statistics.

#### Scenario: Viewing queue depths

- **WHEN** the admin views the status page
- **THEN** the page SHALL show count of pending jobs by type, failed jobs, and last execution time per job type

### Requirement: System statistics

The status page SHALL display key application metrics.

#### Scenario: Viewing system stats

- **WHEN** the admin views the status page
- **THEN** the page SHALL show: total documents by status (inbox/processing/evergreen), last successful backup time, last calendar sync time, document count without embeddings (if applicable)
