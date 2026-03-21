## ADDED Requirements

### Requirement: Document creation service

Document creation logic SHALL be encapsulated in `Documents::CreateService`, callable from controllers, Telegram handler, and API.

#### Scenario: Creating a document from web controller

- **WHEN** `Documents::CreateService.call(title:, body:, document_type:, status:)` is called
- **THEN** the service SHALL create the document, trigger link extraction, and return a successful `ServiceResult` with the document

#### Scenario: Creating a document from Telegram

- **WHEN** `Documents::CreateService.call(title:, body:, document_type:, source: "telegram")` is called
- **THEN** the service SHALL create the document with the same logic as web creation

#### Scenario: Invalid document parameters

- **WHEN** `Documents::CreateService.call(title: "")` is called with missing required fields
- **THEN** the service SHALL return a failed `ServiceResult` with validation errors

### Requirement: Document search service

Document search logic SHALL be encapsulated in `Documents::SearchService`.

#### Scenario: FTS search

- **WHEN** `Documents::SearchService.call(query: "some text", scope: Document.all)` is called
- **THEN** the service SHALL return a successful `ServiceResult` with paginated matching documents
