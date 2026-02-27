# Proposal: Markdown Editor for Text Blocks

## Why

All text content in Inbox — whether typed or transcribed from voice — is currently stored as plain text and rendered in a raw `contenteditable div`. There is no formatting support, no structure, and no visual hierarchy. Users who want to organize notes, create checklists, or add structure to their content have no way to do so.

Adopting Markdown as the content format for text blocks gives users a simple, portable formatting model with minimal learning curve.

## What Changes

- Text blocks store content as Markdown (already backward-compatible — plain text is valid Markdown)
- Viewing a text block renders Markdown to HTML (headings, bold, italic, code, lists, checkboxes)
- Editing a text block uses a `<textarea>` with a "Preview" toggle
- `- [ ]` and `- [x]` checkboxes become interactive (click to toggle, auto-saves)
- Ollama correction/transcription output remains plain text (Markdown rendering handles structure)
- No change to the `content` JSON schema — `content["text"]` still stores the raw string

## Capabilities

### New Capabilities
- `markdown-rendering`: Text blocks render Markdown to HTML using Redcarpet. Supports headings, bold, italic, inline code, fenced code blocks, unordered/ordered lists, and GFM task lists (`- [ ]` / `- [x]`).
- `markdown-editing`: Text block editing switches from `contenteditable div` to a `<textarea>`. A "Preview" button toggles between raw Markdown and rendered output.
- `interactive-checkboxes`: `- [ ]` and `- [x]` items in rendered Markdown are clickable. Toggling a checkbox updates the raw Markdown in the block content and saves via the existing block API.

### Modified Capabilities
- `text-handling` (if exists): text block display now renders Markdown

## Impact

- **Gem**: add `redcarpet` to `Gemfile`
- **Helper**: new `MarkdownHelper` (or `ApplicationHelper` method) wrapping Redcarpet renderer
- **View**: `app/views/blocks/_text.html.erb` — render Markdown HTML in view mode; show textarea in edit mode
- **Stimulus controller**: `document_editor_controller.js` or new `markdown_editor_controller.js` — handle preview toggle and checkbox clicks
- **No database migration needed** — `content["text"]` already stores the text
- **Backward-compatible**: existing plain text content renders correctly as Markdown
