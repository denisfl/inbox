## Requirements

### Requirement: Health check endpoint

The system SHALL provide a `GET /api/health` endpoint that returns the status of each external integration.

#### Scenario: All services healthy

- **WHEN** a client requests `GET /api/health` and all services are reachable
- **THEN** the response SHALL return HTTP 200 with JSON body `{"status": "ok", "services": {"database": "ok", "transcriber": "ok", "google_calendar": "ok"}}`

#### Scenario: Some services unavailable

- **WHEN** a client requests `GET /api/health` and the Transcriber is unreachable
- **THEN** the response SHALL return HTTP 200 with JSON body where `transcriber` is `"unavailable"` and other services show their actual status

#### Scenario: Database unavailable

- **WHEN** a client requests `GET /api/health` and the database is unreachable
- **THEN** the response SHALL return HTTP 503

#### Scenario: Health check timeout

- **WHEN** a health check probe to any service exceeds 5 seconds
- **THEN** the system SHALL report that service as `"unavailable"` without blocking the response
