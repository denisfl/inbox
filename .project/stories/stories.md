# User Stories

## Story 1: Project setup & baseline ✅

As a developer, I want the project baseline fully configured so that the team can start building features confidently.

**Acceptance Criteria**

- Project dependencies installed and lockfile committed
- Environment configuration documented
- Basic scripts (lint/test/build) verified
- Docker setup configured and tested
- CI pipeline skeleton confirmed

**Priority:** P0 (Critical)  
**Complexity:** Medium  
**Dependencies:** None

---

## Story 2: Core data models & database setup

As a developer, I want the core data models (Document, Block, Tag) implemented so that we can store and retrieve notes.

**Acceptance Criteria**

- Document model with title, slug, source, timestamps
- Block polymorphic model supporting multiple block types
- Tag model with many-to-many relationship to Documents
- Database migrations with proper indexes
- Model validations and associations
- RSpec tests for models (80%+ coverage)
- SQLite configured with WAL mode

**Block Types to Support:**

- TextBlock
- HeadingBlock
- TodoBlock
- ImageBlock
- CodeBlock
- QuoteBlock
- LinkBlock
- FileBlock

**Priority:** P0 (Critical)  
**Complexity:** High  
**Dependencies:** Story 1

---

## Story 3: REST API for documents

As a frontend developer, I want REST API endpoints for documents so that I can create, read, update, and delete notes.

**Acceptance Criteria**

- `GET /api/documents` - List all documents (paginated)
- `POST /api/documents` - Create new document
- `GET /api/documents/:id` - Get document with blocks
- `PATCH /api/documents/:id` - Update document metadata
- `DELETE /api/documents/:id` - Delete document
- JSON response schema defined
- Error handling with proper HTTP status codes
- API documentation (OpenAPI/Swagger)
- RSpec request tests for all endpoints
- Token-based authentication

**Priority:** P0 (Critical)  
**Complexity:** High  
**Dependencies:** Story 2

---

## Story 4: Block operations API

As a frontend developer, I want API endpoints for block operations so that I can build the block editor.

**Acceptance Criteria**

- `POST /api/documents/:id/blocks` - Add block to document
- `PATCH /api/documents/:id/blocks/:block_id` - Update block content
- `DELETE /api/documents/:id/blocks/:block_id` - Delete block
- `POST /api/documents/:id/blocks/reorder` - Reorder blocks (drag-drop)
- Block type validation
- Position management (automatic reordering)
- RSpec tests for block operations
- Optimistic locking to prevent conflicts

**Priority:** P0 (Critical)  
**Complexity:** Medium  
**Dependencies:** Story 3

---

## Story 5: Web editor UI (Stimulus JS) ✅

As a user, I want a block-based web editor so that I can create and edit notes in the browser.

**Acceptance Criteria**

- ✅ Stimulus controller for document editor
- ✅ Render blocks dynamically based on type
- ✅ Add new block with keyboard shortcut (Cmd+Enter)
- ✅ Delete block with keyboard shortcut (Cmd+Backspace)
- ✅ Inline editing of block content
- ✅ Responsive design (mobile-friendly)
- ✅ Auto-save on content change (debounced)
- ✅ Loading states and error handling
- ✅ File uploads with Active Storage

**Block Rendering:**

- ✅ TextBlock → contenteditable div
- ✅ HeadingBlock → h1/h2/h3 (selectable level)
- ✅ TodoBlock → checkbox + text
- ✅ CodeBlock → syntax-highlighted pre
- ✅ QuoteBlock → blockquote styling
- ✅ ImageBlock → img tag with upload
- ✅ LinkBlock → clickable link preview
- ✅ FileBlock → file attachment with icon

**Priority:** P0 (Critical)  
**Complexity:** Very High  
**Dependencies:** Story 4  
**Status:** ✅ Complete (35 tests passing)

---

## Story 6: Drag-and-drop block reordering

As a user, I want to reorder blocks by drag-and-drop so that I can organize my notes.

**Acceptance Criteria**

- Drag handle on each block
- Visual feedback during drag (ghost element)
- Drop zones between blocks
- Call reorder API on drop
- Optimistic UI update (instant feedback)
- Rollback on API failure
- Touch support for mobile

**Priority:** P1 (High)  
**Complexity:** Medium  
**Dependencies:** Story 5

---

## Story 7: Full-text search

As a user, I want to search my notes so that I can find information quickly.

**Acceptance Criteria**

- `GET /api/documents/search?q=<query>` endpoint
- SQLite FTS5 full-text search index
- Search across document titles and block content
- Highlight matching text in results
- Search UI in web interface
- Pagination for search results
- Performance: <100ms for typical queries

**Priority:** P1 (High)  
**Complexity:** Medium  
**Dependencies:** Story 3

---

## Story 8: Tag and category system

As a user, I want to tag and categorize my notes so that I can organize them.

**Acceptance Criteria**

- Tag input field in document editor
- `GET /api/documents/search?tag=<tag>` filter endpoint
- `GET /api/documents/search?category=<category>` filter endpoint
- Tag autocomplete (suggest existing tags)
- Display tags on document list
- Tag management (create, delete, rename)

**Priority:** P1 (High)  
**Complexity:** Medium  
**Dependencies:** Story 3

---

## Story 9: Ollama AI classification

As a user, I want automatic note classification so that my notes are organized intelligently.

**Acceptance Criteria**

- Ollama service configured (mistral 4.1GB model)
- `POST /api/documents/:id/classify` endpoint
- `POST /api/documents/:id/extract-tags` endpoint
- Background job for classification (Sidekiq)
- Async processing (no blocking)
- Suggested category and tags returned
- User can accept/reject suggestions
- Timeout handling (30s max)

**Classification Categories:**

- Work, Personal, Ideas, Learning, Tasks, Archive

**Priority:** P2 (Medium)  
**Complexity:** High  
**Dependencies:** Story 2, Story 8

---

## Story 10: Telegram bot integration

As a user, I want to send messages to a Telegram bot so that I can capture notes from my phone.

**Acceptance Criteria**

- Telegram bot registered with @BotFather
- Webhook endpoint: `POST /api/telegram/webhook`
- Handle text messages → Create TextBlock document
- Handle photo messages → Create ImageBlock document
- Handle file attachments → Create FileBlock document
- Handle voice messages → Queue for transcription
- Telegram bot responds with confirmation
- Secret token validation
- RSpec tests for webhook handling

**Priority:** P0 (Critical)  
**Complexity:** High  
**Dependencies:** Story 2

---

## Story 11: Whisper audio transcription

As a user, I want voice messages transcribed automatically so that I can capture audio notes.

**Acceptance Criteria**

- Whisper service configured (base 1.5GB model, Russian)
- Background job for transcription (Sidekiq)
- Download voice file from Telegram
- Transcribe audio with Whisper
- Create TextBlock with transcription
- Attach original audio as FileBlock
- Progress indicator in Telegram
- Timeout handling (5 min max)
- Error handling (unsupported format, too long)

**Priority:** P0 (Critical)  
**Complexity:** Very High  
**Dependencies:** Story 10

---

## Story 12: Automatic backups

As a user, I want automatic backups so that my data is safe.

**Acceptance Criteria**

- Daily backup cron job (2 AM)
- Backup SQLite database + uploads folder
- Retention policy: 7 daily, 4 weekly, 3 monthly
- Backup location: `/backup/` directory
- Backup verification (test restore)
- Notification on backup failure
- Optional encrypted cloud upload (GPG + rclone)

**Priority:** P1 (High)  
**Complexity:** Medium  
**Dependencies:** Story 2

---

## Story 13: Export to Markdown/PDF

As a user, I want to export my notes so that I can use them elsewhere.

**Acceptance Criteria**

- `GET /api/documents/:id/export?format=markdown` endpoint
- `GET /api/documents/:id/export?format=pdf` endpoint
- Markdown export preserves block structure
- PDF export with basic styling
- Include tags and metadata
- Download as file attachment

**Priority:** P2 (Medium)  
**Complexity:** Medium  
**Dependencies:** Story 3

---

## Story 14: Docker deployment on Raspberry Pi

As a user, I want to deploy the system on my Raspberry Pi so that it runs locally.

**Acceptance Criteria**

- docker-compose.yml for production
- Services: web, worker, redis, ollama, whisper
- Environment variable configuration
- systemd service for auto-start
- Health check endpoint: `GET /health`
- Deployment documentation
- Rollback procedure documented
- Resource limits configured (memory, CPU)

**Resource Limits (RPi 5 8GB):**

- web: 500MB memory
- worker: 300MB memory
- ollama: 4.5GB memory
- whisper: 2GB memory (only during transcription)

**Priority:** P0 (Critical)  
**Complexity:** High  
**Dependencies:** All core features

---

## Story 15: Monitoring and logging

As a developer, I want monitoring and logging so that I can troubleshoot issues.

**Acceptance Criteria**

- Structured logging (JSON format)
- Log levels: DEBUG, INFO, WARN, ERROR, FATAL
- Log rotation (7 days active, 30 days total)
- Health check metrics (DB, Redis, Ollama, Whisper)
- Application metrics (response time, queue depth)
- Dashboard (optional: Grafana + Prometheus)
- Alert on critical errors

**Priority:** P1 (High)  
**Complexity:** Medium  
**Dependencies:** Story 14

---

## Story Priority Summary

| Priority          | Stories                   | Total |
| ----------------- | ------------------------- | ----- |
| **P0 (Critical)** | 1, 2, 3, 4, 5, 10, 11, 14 | 8     |
| **P1 (High)**     | 6, 7, 8, 12, 15           | 5     |
| **P2 (Medium)**   | 9, 13                     | 2     |

**MVP Scope:** Stories 1-8, 10-11, 14 (12 stories)  
**Total Estimated Effort:** 4-5 weeks

---
