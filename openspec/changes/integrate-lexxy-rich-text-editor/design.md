## Context

The app uses plain `<textarea>` fields for task and event descriptions, stored as Markdown text in `TEXT` columns. Documents use a custom block-based editor with 3 Stimulus controllers (`simple_editor`, `markdown_editor`, `document_editor`) and a JSON-based block model (`blocks` table with `content TEXT`, `block_type`, `position`). Server-side rendering uses the `redcarpet` gem via `render_markdown()` helper. Active Storage is already configured; Action Text is not yet installed (no `action_text_rich_texts` table). JS is bundled with esbuild, assets served via Propshaft.

**Current pain points:**

- Users must know Markdown syntax — no WYSIWYG
- Three separate Stimulus controllers and custom API endpoints for the document editor add maintenance burden
- No consistency between the simple textarea (tasks/events) and the block-based editor (documents)

## Goals / Non-Goals

**Goals:**

- Replace all Markdown textareas and the custom block editor with Lexxy rich text editor
- Use Action Text as the storage backend for all rich text content
- Provide WYSIWYG editing with Markdown shortcuts for power users
- Migrate existing Markdown content to Action Text HTML
- Reduce custom JS code (remove 3 Stimulus controllers)

**Non-Goals:**

- Attachment support in task/event descriptions (keep it text-only for now; documents already have Active Storage)
- Custom Lexxy plugins or prompts (mentions, custom slash commands)
- Changing the document data model beyond switching from blocks to Action Text (no new features)
- SSR/API changes for the Telegram bot or external integrations — those continue to receive plain text

## Decisions

### 1. Use Action Text with Lexxy gem (not standalone Lexxy JS)

**Decision:** Install `lexxy` gem (`~> 0.1.26.beta`) + `@37signals/lexxy` npm package. Let Lexxy override Action Text defaults so `form.rich_text_area` renders Lexxy instead of Trix.

**Rationale:** Lexxy is designed as a drop-in Action Text replacement. Using the gem gives us form helpers, content sanitization, and attachment handling out of the box. The alternative (standalone JS) would require building all Rails integration manually.

**Trade-off:** Beta gem — may have bugs. Mitigation: pin to a specific version, test thoroughly.

### 2. Add `has_rich_text` to models instead of existing TEXT columns

**Decision:** Add `has_rich_text :description` to `Task`, `CalendarEvent`, and `Document` models. This stores content in `action_text_rich_texts` table rather than the model's own `description` column.

**Rationale:** Action Text's polymorphic storage is the standard Rails pattern. It supports embedded attachments and consistent rendering. Keeping the old TEXT columns alongside (deprecated but not removed) allows rollback.

**Alternative considered:** Keep TEXT columns and only use Lexxy as a JS editor widget — rejected because it wouldn't give us Action Text's rendering pipeline and attachment system.

### 3. Two-phase migration for documents

**Decision:** Phase 1: Tasks and events (simple — one TEXT column each). Phase 2: Documents (complex — block-based model with multiple block types, images, files).

**Rationale:** Tasks/events are straightforward: convert Markdown text → HTML → Action Text. Documents require merging multiple blocks back into a single rich text body and re-attaching Active Storage blobs. Separating phases reduces risk.

### 4. Markdown-to-HTML conversion for existing data

**Decision:** Use Redcarpet (already in the project) to convert existing Markdown content to HTML during migration, then wrap it in Action Text records. Keep `redcarpet` gem until migration is complete, then remove it.

**Rationale:** Redcarpet is already configured with the exact rendering options used in the app. Reusing it ensures converted content matches what users saw before.

### 5. Keep old TEXT columns as backup (deprecate, don't remove)

**Decision:** After migration, mark old `description` TEXT columns as deprecated. Do not drop them in the same release. Remove in a follow-up change after confirming Action Text data is correct.

**Rationale:** Allows rollback to Markdown rendering if issues arise. No data loss during transition.

### 6. Remove custom document block editor

**Decision:** Remove `simple_editor_controller.js`, `markdown_editor_controller.js`, `document_editor_controller.js` Stimulus controllers. Remove block-related API endpoints (`api/blocks`). The `blocks` table can be deprecated (not dropped) after migration.

**Rationale:** Lexxy replaces all this functionality with a single rich text area. Keeping dead code increases maintenance.

### 7. Use `form.rich_text_area` in all forms

**Decision:** Replace `<textarea>` with `form.rich_text_area :description` in task form, event form, and document edit view. Lexxy overrides this helper by default.

**Rationale:** Minimal view changes — just swap the form helper. All Lexxy configuration (toolbar, features) comes from the gem defaults.

## Risks / Trade-offs

- **[Beta gem instability]** → Pin exact version, test all CRUD flows. Have Markdown fallback available (old columns preserved)
- **[Document block migration complexity]** → Block types (image, file, code, quote) need careful HTML conversion rules. Test with real data before deploying
- **[Action Text performance with large documents]** → Action Text loads rich text eagerly in some cases. Use `with_rich_text_description` scope for includes
- **[Breaking API for Telegram bot]** → Bot sends plain text. Controller must accept plain text and wrap in Action Text. Add adapter in `process_telegram_update_job.rb`
- **[Lexxy CSS conflicts with existing design system]** → Lexxy ships its own styles. May need to scope or override to match existing design tokens (`--color-*`, `--text-*`). Test in both light/dark themes
- **[Content display in places that currently use render_markdown]** → Calendar popup, dashboard event list, task description preview — all switch to `@task.description.body` or `.to_plain_text` for previews

## Migration Plan

### Phase 1: Infrastructure

1. Install Action Text (`rails action_text:install`, run migration)
2. Add `lexxy` gem to Gemfile, `@37signals/lexxy` to package.json
3. Import Lexxy in `application.js`
4. Add Lexxy stylesheet to asset pipeline

### Phase 2: Tasks & Events

5. Add `has_rich_text :description` to `Task` and `CalendarEvent`
6. Replace `<textarea>` with `form.rich_text_area` in task and event forms
7. Write data migration: convert `tasks.description` and `calendar_events.description` Markdown → HTML → ActionText::RichText records
8. Update views: `render_markdown(@task.description)` → `@task.description` (Action Text auto-renders)
9. Update task description preview in `_task.html.erb` to use `.to_plain_text`

### Phase 3: Documents

10. Add `has_rich_text :body` to `Document`
11. Replace custom block editor with single `form.rich_text_area :body`
12. Write data migration: merge blocks (text, heading, code, quote, todo) into single HTML body, re-attach images/files as Action Text attachments
13. Remove block-related API endpoints and Stimulus controllers
14. Update document display views

### Phase 4: Cleanup

15. Remove `redcarpet` gem
16. Remove `render_markdown` helper and specs
17. Remove old editor CSS classes
18. Deprecate `blocks` table and `description` TEXT columns (do not drop yet)

### Rollback Strategy

- Old TEXT columns are preserved — revert models to use those columns
- Keep `redcarpet` gem in a separate branch for emergency revert
- Action Text records can be deleted if rolling back

## Open Questions

- Should the Lexxy toolbar be customized (e.g., hide code block for tasks/events but keep for documents)?
- Should existing document images/files be migrated as standard Action Text attachments or keep the current Active Storage direct approach?
- How should the API respond — with HTML (Action Text body) or plain text? Current API returns JSON with markdown content
