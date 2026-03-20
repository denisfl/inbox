## Why

The app currently relies on plain `<textarea>` fields with server-side Redcarpet markdown rendering for task descriptions, event descriptions, and the document block editor. Users must know Markdown syntax to format text. Lexxy (Basecamp's Lexical-based rich text editor for Rails) provides a modern WYSIWYG editing experience with Markdown shortcuts, real-time code highlighting, link pasting, and seamless Action Text integration — making rich text editing accessible without requiring Markdown knowledge.

## What Changes

- Install the `lexxy` gem and its npm package as project dependencies
- Set up Action Text infrastructure (install, migrations) to store rich text content
- Replace plain `<textarea>` for **task descriptions** with Lexxy editor
- Replace plain `<textarea>` for **event descriptions** with Lexxy editor
- Replace the custom block-based document editor (simple-editor + markdown-editor + document-editor Stimulus controllers) with Lexxy editor
- **BREAKING**: Migrate existing plain Markdown content in `tasks.description`, `calendar_events.description`, and `blocks.content` to Action Text rich text format
- Remove Redcarpet gem and `render_markdown` helper after migration (replaced by Action Text's built-in rendering)
- Remove custom Stimulus controllers (`simple_editor_controller.js`, `markdown_editor_controller.js`, `document_editor_controller.js`) that are no longer needed
- Update all views that display rendered content to use Action Text's `.body` rendering instead of `render_markdown()`

## Capabilities

### New Capabilities

- `lexxy-rich-text-editor`: Core Lexxy editor integration — gem/npm setup, Action Text configuration, editor component with toolbar, content rendering pipeline

### Modified Capabilities

- `weekly-timeline`: Event popup and event form description fields change from Markdown textarea to Lexxy rich text editor; rendered output changes from `render_markdown()` to Action Text body

## Impact

- **Dependencies**: Add `lexxy` gem + `@basecamp/lexxy` npm package; remove `redcarpet` gem after migration
- **Database**: New Action Text tables (`action_text_rich_texts`, `active_storage_blobs` if not present); data migration for existing descriptions
- **JavaScript**: Remove 3 custom Stimulus controllers; Lexxy ships its own JS. Rebuild required (`pnpm run build`)
- **CSS**: Lexxy provides its own styles; custom editor CSS (simple-editor, markdown-editor classes) can be removed
- **Views**: All forms using `<textarea>` for descriptions switch to `lexxy_editor` helper. All display views switch from `render_markdown()` to Action Text rendering
- **API**: `api/documents` controller and block-related endpoints may need updates since document storage model changes from custom blocks to Action Text
- **Tests**: Helper specs for `render_markdown` removed; new specs for rich text content rendering
