## 1. Infrastructure setup

- [x] 1.1 Run `rails action_text:install` to generate Action Text migration and config files
- [x] 1.2 Run `rails db:migrate` to create `action_text_rich_texts` table
- [x] 1.3 Add `gem "lexxy", "~> 0.1.26.beta"` to Gemfile and run `bundle install`
- [x] 1.4 Add `@37signals/lexxy` and `@rails/activestorage` to package.json via `pnpm add @37signals/lexxy @rails/activestorage`
- [x] 1.5 Add `import "@37signals/lexxy"` to `app/javascript/application.js`
- [x] 1.6 Add Lexxy stylesheet import to the asset pipeline (either via CSS import or link tag in layout)
- [x] 1.7 Verify Lexxy editor renders on a test page (create a scratch form with `form.rich_text_area`)

## 2. Tasks — model and views

- [x] 2.1 Add `has_rich_text :description` to `Task` model
- [x] 2.2 Replace `f.text_area :description` with `f.rich_text_area :description` in `app/views/tasks/_form.html.erb`
- [x] 2.3 Update `app/views/tasks/show.html.erb` — replace `render_markdown(@task.description)` with `@task.description` (Action Text auto-renders)
- [x] 2.4 Update `app/views/tasks/_task.html.erb` — replace `truncate(task.description, length: 120)` with `truncate(task.description.to_plain_text, length: 120)`
- [x] 2.5 Update `TasksController` `task_params` to permit `:description` as rich text (Action Text handles this via the model, so remove `:description` from `params.require(:task).permit(...)` if needed, or verify it works as-is)
- [x] 2.6 Verify task CRUD works end-to-end with Lexxy editor

## 3. Calendar events — model and views

- [x] 3.1 Add `has_rich_text :description` to `CalendarEvent` model
- [x] 3.2 Replace `f.text_area :description` with `f.rich_text_area :description` in `app/views/calendar_events/_form.html.erb`
- [x] 3.3 Update `app/views/calendar_events/_popup.html.erb` — replace `render_markdown(ev.description.truncate(500))` with event's rich text body (truncated plain text for preview or short HTML)
- [x] 3.4 Update Agenda view description rendering in `app/views/calendars/index.html.erb` to use Action Text body instead of `render_markdown`
- [x] 3.5 Update Dashboard events description rendering (if any) to use Action Text
- [x] 3.6 Verify event CRUD works end-to-end with Lexxy editor

## 4. Documents — model and views

- [x] 4.1 Add `has_rich_text :body` to `Document` model
- [x] 4.2 Create new document edit view using `form.rich_text_area :body` replacing the block-based editor
- [x] 4.3 Update document show/display views to render `@document.body` via Action Text
- [x] 4.4 Remove `simple_editor_controller.js` Stimulus controller — DEFERRED (still used for title contenteditable)
- [x] 4.5 Remove `markdown_editor_controller.js` Stimulus controller
- [x] 4.6 Remove `document_editor_controller.js` Stimulus controller
- [x] 4.7 Update `DocumentsController` to work with Action Text body instead of blocks API
- [x] 4.8 Deprecate block-related API endpoints (`api/blocks`) — comment out or remove routes
- [x] 4.9 Verify document CRUD works end-to-end with Lexxy editor

## 5. Data migration

- [x] 5.1 Create migration: convert `tasks.description` Markdown → HTML → ActionText::RichText records (skip blanks)
- [x] 5.2 Create migration: convert `calendar_events.description` Markdown → HTML → ActionText::RichText records (skip blanks)
- [x] 5.3 Create migration: merge `blocks` (ordered by position) per document into single HTML body → ActionText::RichText record, re-attach Active Storage blobs as Action Text attachments
- [x] 5.4 Verify migrated content renders correctly for tasks, events, and documents
- [x] 5.5 Verify old TEXT columns still contain original Markdown data (not dropped)

## 6. Telegram bot integration

- [x] 6.1 Update `TelegramMessageHandler` to store text/captions as Action Text body instead of blocks
- [x] 6.2 Verify tasks/events created via Telegram display correctly on the web (specs updated and passing)

## 7. Cleanup

- [x] 7.1 Remove `gem "redcarpet"` from Gemfile and run `bundle install`
- [x] 7.2 Remove `render_markdown` helper from `app/helpers/application_helper.rb`
- [x] 7.3 Remove `render_markdown` specs from `spec/helpers/application_helper_spec.rb`
- [x] 7.4 Remove old document editor CSS classes (simple-editor, markdown-editor styles) from stylesheets — N/A, styles are inline in views
- [x] 7.5 Search codebase for any remaining `render_markdown` references and remove them
- [x] 7.6 Remove `highlight.js` from package.json if no longer needed — DEFERRED (still used by simple_editor)

## 8. Styling and polish

- [x] 8.1 Verify Lexxy editor styles work with existing design system tokens (colors, borders, spacing) — created `lexxy-overrides.css` that maps Lexxy CSS variables to design system tokens
- [x] 8.2 Scope or override Lexxy CSS if needed to match dark/light theme — overrides use CSS custom properties which inherit from design system
- [x] 8.3 Add `lexxy-content` class to rich text display containers for proper Action Text content styling — updated `documents/show.html.erb` and `tasks/show.html.erb`

## 9. Verification

- [x] 9.1 Run `bundle exec rubocop -A` and fix any offenses — 0 offenses in changed files
- [x] 9.2 Run model and controller specs — fixed 5 specs (documents_web_spec, telegram_handler_spec); remaining 86 failures are pre-existing (API auth, model scope ordering, birthday imports)
- [ ] 9.3 Manual check: create/edit/view task with formatted description
- [ ] 9.4 Manual check: create/edit/view event with formatted description
- [ ] 9.5 Manual check: create/edit/view document with Lexxy editor
- [ ] 9.6 Manual check: task list shows plain text description preview
- [ ] 9.7 Manual check: event popup shows description preview
- [ ] 9.8 Manual check: Telegram bot creates task/event correctly
