## ADDED Requirements

### Requirement: Critical path integration tests

The test suite SHALL include integration tests verifying end-to-end critical user journeys.

#### Scenario: Telegram voice note to document

- **WHEN** a Telegram voice message webhook is received
- **THEN** the system processes it through TelegramMessageHandler → TranscribeAudioJob → document creation with transcribed content

#### Scenario: Wiki-link resolution

- **WHEN** a document body contains `[[Target Title]]` and a document with that title exists
- **THEN** the document's rendered HTML SHALL contain a live wiki-link pointing to the target

#### Scenario: Document API CRUD

- **WHEN** a client creates, reads, updates, and deletes a document via the API
- **THEN** each operation SHALL succeed and the database SHALL reflect the changes

#### Scenario: Calendar sync and event reminder

- **WHEN** GoogleCalendarSyncJob syncs events and SendEventReminderJob runs
- **THEN** events are created in the database and reminders are sent for qualifying events

### Requirement: Semantic search integration

The system SHALL have an integration test verifying the search pipeline.

#### Scenario: Document search returns results

- **GIVEN** a document exists with specific content
- **WHEN** a search query matching that content is submitted
- **THEN** the search results SHALL include that document
