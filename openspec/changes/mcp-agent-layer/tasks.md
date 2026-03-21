## Tasks

### Group 1: MCP infrastructure

- [ ] 1.1 Create `app/mcp/base_tool.rb` — base class with `name`, `description`, `input_schema`, `call(input)`, and `writes?` flag
- [ ] 1.2 Create `app/mcp/tool_registry.rb` — auto-discovers tools from `app/mcp/tools/`, provides `find(name)`, `all`, `schemas`
- [ ] 1.3 Write gate: `BaseTool` checks `ENV["ALLOW_MCP_WRITES"]` for write tools, raises error if disabled

### Group 2: Read-only tools

- [ ] 2.1 `Mcp::Tools::ListDocuments` — list documents with optional status/limit filters
- [ ] 2.2 `Mcp::Tools::GetDocument` — get document by id with body content
- [ ] 2.3 `Mcp::Tools::SearchDocuments` — search documents by query string
- [ ] 2.4 `Mcp::Tools::ListTasks` — list tasks with optional status filter (active/completed)
- [ ] 2.5 `Mcp::Tools::GetTask` — get task by id
- [ ] 2.6 `Mcp::Tools::ListCalendarEvents` — list calendar events with optional date range
- [ ] 2.7 `Mcp::Tools::GetCalendarEvent` — get calendar event by id

### Group 3: Write tools

- [ ] 3.1 `Mcp::Tools::CreateDocument` — create document with title and body
- [ ] 3.2 `Mcp::Tools::UpdateDocument` — update document title/body/status
- [ ] 3.3 `Mcp::Tools::DeleteDocument` — delete document by id
- [ ] 3.4 `Mcp::Tools::CreateTask` — create task with title and optional due date
- [ ] 3.5 `Mcp::Tools::CompleteTask` — mark task as completed

### Group 4: Controller and routes

- [ ] 4.1 Create `app/controllers/api/v1/mcp_controller.rb` with `execute` and `tools` actions
- [ ] 4.2 `execute`: validate tool exists, validate input against schema, call tool, return result
- [ ] 4.3 `tools`: return all tool schemas as JSON
- [ ] 4.4 Add routes: `POST /api/v1/mcp/execute`, `GET /api/v1/mcp/tools`

### Group 5: Configuration

- [ ] 5.1 Add `ALLOW_MCP_WRITES` to `.env.example` (default: false)
- [ ] 5.2 Document MCP tools and usage in `docs/mcp.md`

### Group 6: Tests

- [ ] 6.1 Unit tests for each tool — verify correct output for valid input
- [ ] 6.2 Test write gate — write tools rejected when `ALLOW_MCP_WRITES` is false
- [ ] 6.3 Request spec for `POST /api/v1/mcp/execute` — valid call, invalid tool, invalid input, auth required
- [ ] 6.4 Request spec for `GET /api/v1/mcp/tools` — returns all schemas
- [ ] 6.5 Test tool registry auto-discovery loads all tools
