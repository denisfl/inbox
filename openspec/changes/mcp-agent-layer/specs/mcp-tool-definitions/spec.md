## ADDED Requirements

### Requirement: MCP tool definitions

The system SHALL provide MCP-compatible tool definitions for core resources.

#### Scenario: Document tools

- **GIVEN** the MCP tool registry
- **THEN** it SHALL include tools: `list_documents`, `get_document`, `search_documents`, `create_document`, `update_document`, `delete_document`

#### Scenario: Task tools

- **GIVEN** the MCP tool registry
- **THEN** it SHALL include tools: `list_tasks`, `get_task`, `create_task`, `complete_task`

#### Scenario: Calendar tools

- **GIVEN** the MCP tool registry
- **THEN** it SHALL include tools: `list_calendar_events`, `get_calendar_event`

#### Scenario: Tool schema

- **GIVEN** any MCP tool
- **THEN** it SHALL define: `name`, `description`, `input_schema` (JSON Schema), and `output_schema`

### Requirement: Read-only by default

Write operations SHALL be disabled by default and gated behind a configuration flag.

#### Scenario: Writes disabled (default)

- **WHEN** `ALLOW_MCP_WRITES` is not set or is `false`
- **AND** an agent calls `create_document`
- **THEN** the system SHALL return an error: "Write operations are disabled"

#### Scenario: Writes enabled

- **WHEN** `ALLOW_MCP_WRITES=true`
- **AND** an agent calls `create_document` with valid parameters
- **THEN** the system SHALL create the document and return the result
