## Requirements

### Requirement: Domain event publishing

Core models SHALL publish domain events via `ActiveSupport::Notifications` on lifecycle changes.

#### Scenario: Document created event

- **WHEN** a new Document is saved for the first time
- **THEN** the system SHALL publish a `document.created` event with the document's id and attributes

#### Scenario: Document updated event

- **WHEN** an existing Document is saved with changes
- **THEN** the system SHALL publish a `document.updated` event with the document's id and changed attributes

#### Scenario: Document deleted event

- **WHEN** a Document is destroyed
- **THEN** the system SHALL publish a `document.deleted` event with the document's id

#### Scenario: Task lifecycle events

- **WHEN** a Task is created, completed, or uncompleted
- **THEN** the system SHALL publish `task.created`, `task.completed`, or `task.uncompleted` events respectively

### Requirement: Event payload structure

Each published event SHALL include a consistent payload structure.

#### Scenario: Event payload

- **GIVEN** any domain event is published
- **THEN** the payload SHALL include: `model_class`, `model_id`, `action`, `changes` (if applicable), and `timestamp`
