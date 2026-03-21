## ADDED Requirements

### Requirement: Backup status in health check
The system SHALL expose the last backup status through the health-check endpoint.

#### Scenario: Successful last backup
- **WHEN** a client requests `GET /api/health`
- **THEN** the response SHALL include `"backup": {"status": "ok", "last_backup_at": "<ISO8601 timestamp>", "size_bytes": <integer>}`

#### Scenario: Last backup failed
- **WHEN** the most recent backup job failed
- **THEN** the response SHALL include `"backup": {"status": "failed", "last_success_at": "<ISO8601 timestamp or null>", "last_error": "<error message>"}`

#### Scenario: No backup ever run
- **WHEN** no backup has been executed yet
- **THEN** the response SHALL include `"backup": {"status": "never_run"}`
