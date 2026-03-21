## Why

The MCP (Model Context Protocol) standard allows AI agents to interact with applications through a structured tool interface. Adding an MCP layer to Inbox would let AI assistants (GitHub Copilot, Claude, etc.) read and manage notes, tasks, and calendar events programmatically — enabling workflows like "create a note from this conversation" or "show me my tasks for today."

Currently, the only programmatic entry points are the REST API and the Telegram bot. An MCP layer provides a standardized, agent-friendly interface with tool definitions, schema validation, and read-only-by-default safety.

## What Changes

- MCP tool definitions for documents, tasks, and calendar events (CRUD + search)
- MCP execute endpoint at `POST /api/v1/mcp/execute`
- Read-only by default — write operations gated behind `ALLOW_MCP_WRITES` ENV flag
- Tools organized in `app/mcp/tools/` directory

## Capabilities

### New Capabilities

- `mcp-tool-definitions`: MCP-compatible tool definitions for documents, tasks, and calendar events
- `mcp-execute-endpoint`: HTTP endpoint for executing MCP tool calls with schema validation

### Modified Capabilities

<!-- No existing capabilities modified -->

## Impact

- **New files**: `app/mcp/tools/` directory with tool classes, `app/controllers/api/v1/mcp_controller.rb`, `app/mcp/tool_registry.rb`
- **Modified files**: `config/routes.rb` (add MCP endpoint)
- **Dependencies**: None (JSON Schema for validation can be done with native Ruby)
- **Config**: `ALLOW_MCP_WRITES` ENV variable (default: false)
