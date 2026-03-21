## ADDED Requirements

### Requirement: Event subscriber infrastructure
The system SHALL support registering subscriber classes that react to domain events.

#### Scenario: Wiki-link extraction subscriber
- **WHEN** a `document.created` or `document.updated` event is published
- **THEN** the `WikiLinkExtractionSubscriber` SHALL extract wiki-links from the document body

#### Scenario: Subscriber registration
- **GIVEN** subscribers are registered in an initializer
- **THEN** each subscriber SHALL be activated at boot time and respond to its subscribed events

#### Scenario: Subscriber isolation
- **WHEN** a subscriber raises an error
- **THEN** the error SHALL be logged and other subscribers SHALL continue processing
