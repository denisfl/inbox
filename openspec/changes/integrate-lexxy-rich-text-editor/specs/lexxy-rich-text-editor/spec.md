## ADDED Requirements

### Requirement: Lexxy gem and Action Text are installed

The application SHALL have `lexxy` gem and `@37signals/lexxy` npm package installed. Action Text infrastructure (migration, tables) SHALL be configured. Lexxy SHALL override the default Action Text form helpers so `form.rich_text_area` renders a Lexxy editor.

#### Scenario: Lexxy gem is present

- **WHEN** the application boots
- **THEN** `Lexxy` module is available and Action Text uses Lexxy as the editor

#### Scenario: Action Text tables exist

- **WHEN** the database is migrated
- **THEN** `action_text_rich_texts` table exists with columns for `record_type`, `record_id`, `name`, and `body`

#### Scenario: Lexxy JS is loaded

- **WHEN** a page with a rich text area is loaded
- **THEN** the Lexxy editor UI renders with toolbar (bold, italic, links, code, lists, etc.)

### Requirement: Task description uses Lexxy rich text editor

The `Task` model SHALL use `has_rich_text :description`. The task form SHALL render a Lexxy editor for the description field via `form.rich_text_area :description`. The task show page SHALL render the rich text body directly.

#### Scenario: Task form shows Lexxy editor

- **WHEN** user navigates to new task or edit task page
- **THEN** the description field displays a Lexxy rich text editor instead of a plain textarea

#### Scenario: Task description is saved as rich text

- **WHEN** user enters formatted content (bold, links, lists) in the task description and saves
- **THEN** the task's `description` Action Text record stores the HTML content

#### Scenario: Task show page renders rich text

- **WHEN** user views a task with a formatted description
- **THEN** the description renders as styled HTML (bold, links, lists preserved)

#### Scenario: Task list shows plain text preview

- **WHEN** a task with rich text description is displayed in the task list
- **THEN** the description preview shows truncated plain text (via `.to_plain_text`)

### Requirement: Calendar event description uses Lexxy rich text editor

The `CalendarEvent` model SHALL use `has_rich_text :description`. The event form SHALL render a Lexxy editor for the description field. The event popup SHALL render truncated rich text or plain text preview.

#### Scenario: Event form shows Lexxy editor

- **WHEN** user navigates to new event or edit event page
- **THEN** the description field displays a Lexxy rich text editor

#### Scenario: Event description is saved as rich text

- **WHEN** user enters formatted content in the event description and saves
- **THEN** the event's `description` Action Text record stores the HTML content

#### Scenario: Event popup shows description preview

- **WHEN** user clicks a calendar event to see its popup
- **THEN** the description is displayed as rendered rich text (truncated if long)

### Requirement: Document uses Lexxy rich text editor

The `Document` model SHALL use `has_rich_text :body`. The document edit page SHALL render a single Lexxy editor for the full document body, replacing the block-based editor. The custom Stimulus controllers (`simple_editor`, `markdown_editor`, `document_editor`) SHALL be removed.

#### Scenario: Document edit shows Lexxy editor

- **WHEN** user opens a document for editing
- **THEN** a single Lexxy rich text editor is displayed for the document body

#### Scenario: Document body is saved as rich text

- **WHEN** user edits document content and saves
- **THEN** the document's `body` Action Text record stores the HTML content

#### Scenario: Custom block editor controllers are removed

- **WHEN** the application JS bundle is built
- **THEN** `simple_editor_controller.js`, `markdown_editor_controller.js`, `document_editor_controller.js` are no longer present

### Requirement: Existing Markdown content is migrated to Action Text

A data migration SHALL convert existing Markdown text in `tasks.description`, `calendar_events.description`, and `blocks.content` into Action Text HTML records. The migration SHALL use Redcarpet to render Markdown to HTML before storing as Action Text.

#### Scenario: Task with Markdown description is migrated

- **WHEN** migration runs on a task with `description` containing `**bold** text`
- **THEN** an ActionText::RichText record is created with body containing `<strong>bold</strong> text`

#### Scenario: Event with Markdown description is migrated

- **WHEN** migration runs on an event with `description` containing `- item 1\n- item 2`
- **THEN** an ActionText::RichText record is created with body containing an HTML list

#### Scenario: Document blocks are merged into single rich text body

- **WHEN** migration runs on a document with 3 blocks (heading, text, code)
- **THEN** a single ActionText::RichText record is created with body containing all blocks' content as HTML in order

#### Scenario: Empty descriptions are skipped

- **WHEN** migration runs on a task with blank description
- **THEN** no ActionText::RichText record is created for that task

### Requirement: Old TEXT columns are preserved after migration

The migration SHALL NOT drop original `description` TEXT columns from `tasks` and `calendar_events` tables, nor the `blocks` table. These columns SHALL be deprecated and available for rollback.

#### Scenario: Old column still readable after migration

- **WHEN** migration completes and a task's original `description` column is queried
- **THEN** the original Markdown text is still present

#### Scenario: Blocks table is preserved

- **WHEN** migration completes
- **THEN** the `blocks` table and its data still exist in the database

### Requirement: Redcarpet gem and render_markdown helper are removed

After migration is confirmed successful, the `redcarpet` gem SHALL be removed from the Gemfile. The `render_markdown` helper in `ApplicationHelper` SHALL be removed. All views SHALL use Action Text rendering instead.

#### Scenario: render_markdown is no longer used

- **WHEN** the codebase is searched for `render_markdown`
- **THEN** no references exist in views or helpers (only in migration code if retained)

#### Scenario: Redcarpet gem is removed

- **WHEN** `Gemfile` is inspected
- **THEN** `redcarpet` is not listed as a dependency

### Requirement: Telegram bot plain text input is preserved

The `ProcessTelegramUpdateJob` SHALL continue to accept plain text input from the Telegram bot. When creating tasks or events via Telegram, plain text SHALL be wrapped into Action Text content.

#### Scenario: Telegram creates task with plain text

- **WHEN** a Telegram message creates a task with description "Buy groceries"
- **THEN** the task's Action Text description contains `<div class="trix-content">Buy groceries</div>` or equivalent

#### Scenario: Telegram plain text is rendered correctly

- **WHEN** a task created via Telegram is viewed on the web
- **THEN** the description displays "Buy groceries" as plain text content
