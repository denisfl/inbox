## Requirements

### Requirement: Configurable timeouts for all external HTTP calls

The system SHALL enforce explicit timeouts on every HTTP call to external services.

#### Scenario: Transcriber timeout

- **WHEN** an HTTP call to the Transcriber service exceeds 600 seconds
- **THEN** the system SHALL raise a timeout error and log it with `[transcriber]` tag

#### Scenario: Telegram file download timeout

- **WHEN** a Telegram file download exceeds 30 seconds
- **THEN** the system SHALL raise a timeout error instead of hanging indefinitely

#### Scenario: Google Calendar API timeout

- **WHEN** a Google Calendar API call exceeds 15 seconds
- **THEN** the system SHALL raise a timeout error and log it with `[google_calendar]` tag

### Requirement: Retry with exponential backoff

The system SHALL retry failed HTTP calls to external services with exponential backoff.

#### Scenario: Transient network failure

- **WHEN** an HTTP call to an external service fails with a network error (connection refused, timeout, DNS failure)
- **THEN** the system SHALL retry up to 3 times with exponential backoff (1s, 4s, 9s)

#### Scenario: Permanent failure (4xx response)

- **WHEN** an HTTP call returns a 4xx client error (except 429 Too Many Requests)
- **THEN** the system SHALL NOT retry and SHALL log the error immediately

#### Scenario: Rate limiting (429)

- **WHEN** an HTTP call returns a 429 Too Many Requests response
- **THEN** the system SHALL retry after the `Retry-After` header value, or after 60 seconds if header is absent

### Requirement: Graceful degradation

Unavailability of one external service SHALL NOT affect the functionality of other services.

#### Scenario: Transcriber is down during Telegram voice message

- **WHEN** a voice message is received via Telegram and the Transcriber service is unavailable
- **THEN** the system SHALL save the document with the audio attachment and queue transcription for later retry, without affecting other Telegram message processing

#### Scenario: Google Calendar is down during sync

- **WHEN** the Google Calendar sync job runs and Google Calendar API is unavailable
- **THEN** the system SHALL log the failure, schedule a retry, and not affect document or task operations

### Requirement: Structured error logging

The system SHALL log all external service interactions with structured tags.

#### Scenario: Successful external call

- **WHEN** an HTTP call to an external service succeeds
- **THEN** the system SHALL log the call at `debug` level with tags `[service_name]`, method, URL, and response time
