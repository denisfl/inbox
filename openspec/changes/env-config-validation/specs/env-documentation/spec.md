## ADDED Requirements

### Requirement: Comprehensive .env.example

The repository SHALL maintain a `.env.example` file documenting every environment variable with inline comments.

#### Scenario: Variable documentation

- **GIVEN** `.env.example` exists
- **THEN** each variable SHALL have a comment describing its purpose, whether it's required or optional, and its default value (if optional)

#### Scenario: Grouped by domain

- **GIVEN** `.env.example` exists
- **THEN** variables SHALL be organized by domain: Rails Core, Database, Telegram, Transcriber, Calendar, API, Backup, Observability
