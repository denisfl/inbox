## ADDED Requirements

### Requirement: MCP execute endpoint

The system SHALL provide an HTTP endpoint for executing MCP tool calls.

#### Scenario: Valid tool call

- **WHEN** a POST request to `/api/v1/mcp/execute` includes `{ "tool": "list_documents", "input": {} }`
- **THEN** the system SHALL execute the tool and return the result as JSON

#### Scenario: Invalid tool name

- **WHEN** a POST request specifies a non-existent tool
- **THEN** the system SHALL return HTTP 404 with error details

#### Scenario: Invalid input schema

- **WHEN** a POST request includes input that doesn't match the tool's schema
- **THEN** the system SHALL return HTTP 422 with validation errors

#### Scenario: Authentication required

- **WHEN** a POST request is sent without a valid API token
- **THEN** the system SHALL return HTTP 401

#### Scenario: Tool listing

- **WHEN** a GET request is sent to `/api/v1/mcp/tools`
- **THEN** the system SHALL return the complete list of available tools with their schemas
