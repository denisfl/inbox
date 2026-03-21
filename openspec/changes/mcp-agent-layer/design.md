## Context

The app has a REST API at `/api/` (moving to `/api/v1/`) with token authentication. The service layer extraction (planned) will provide reusable service objects. MCP tools can delegate to these services rather than duplicating controller logic. The Telegram bot already demonstrates a non-web entry point using the same services.

## Decisions

### 1. Tools as plain Ruby classes in `app/mcp/tools/`

**Rationale**: Each tool is a class with `name`, `description`, `input_schema`, and `call(input)` method. No framework dependency — just Ruby classes registered in a tool registry.

```ruby
# app/mcp/tools/list_documents.rb
class Mcp::Tools::ListDocuments < Mcp::BaseTool
  def self.name = "list_documents"
  def self.description = "List all documents with optional filtering"
  def self.input_schema = { type: "object", properties: { status: { type: "string" }, limit: { type: "integer" } } }

  def call(input)
    documents = Document.all
    documents = documents.where(status: input["status"]) if input["status"]
    documents = documents.limit(input["limit"] || 20)
    { documents: documents.map { |d| serialize(d) } }
  end
end
```

### 2. Tool registry with auto-discovery

**Rationale**: `Mcp::ToolRegistry` loads all tool classes from `app/mcp/tools/` at boot. Provides `find(name)`, `all`, and `schemas` methods. New tools are added by creating a class — no registration needed.

### 3. Write gate via `ALLOW_MCP_WRITES` ENV

**Rationale**: AI agents can be unpredictable. Read-only by default prevents accidental data modification. The gate is checked in `BaseTool` — write tools declare `writes: true` and are rejected if the flag is off.

### 4. Single execute endpoint + tools listing

**Rationale**: `POST /api/v1/mcp/execute` with `{ tool: "name", input: {} }` body — standard MCP pattern. `GET /api/v1/mcp/tools` returns all tool schemas for agent discovery. Both protected by the same API token auth as the REST API.

### 5. Delegate to service layer

**Rationale**: When the service layer extraction is complete, MCP tools will call service objects (e.g., `Documents::SearchService`). Until then, tools can use ActiveRecord directly. The interface stays the same.

## Risks

1. **Schema explosion**: As tools grow, maintaining JSON Schema definitions becomes tedious. Mitigate by keeping schemas minimal and generating from tool method signatures.
2. **Security**: Write operations must be carefully validated. The `ALLOW_MCP_WRITES` flag is a hard gate, not a suggestion.
3. **MCP protocol evolution**: The MCP standard is still evolving. Design tools as plain Ruby so they're protocol-independent — the controller handles protocol details.

## Implementation order

1. Create `Mcp::BaseTool` base class with schema, write gate, and serialization
2. Create `Mcp::ToolRegistry` with auto-discovery
3. Implement read-only tools: `list_documents`, `get_document`, `search_documents`, `list_tasks`, `get_task`, `list_calendar_events`, `get_calendar_event`
4. Implement write tools: `create_document`, `update_document`, `delete_document`, `create_task`, `complete_task`
5. Create `Api::V1::McpController` with `execute` and `tools` actions
6. Add routes and tests
