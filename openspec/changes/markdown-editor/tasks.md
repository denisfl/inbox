## 1. Gem: Redcarpet

- [ ] 1.1 Add `gem "redcarpet"` to `Gemfile`
- [ ] 1.2 Run `bundle install`

## 2. MarkdownHelper

- [ ] 2.1 Add `render_markdown(text)` to `app/helpers/application_helper.rb`:
  - Use `Redcarpet::Render::HTML` with `hard_wrap: true`, `link_attributes: { target: "_blank", rel: "noopener" }`
  - Enable extensions: `autolink`, `tables`, `fenced_code_blocks`, `strikethrough`, `lax_spacing`, `no_intra_emphasis`
  - Post-process rendered HTML: strip `disabled` from `<input type="checkbox">` tags → add `data-action="change->markdown-editor#toggleCheckbox"`
  - Return `html_safe` string

## 3. Text Block View (`_text.html.erb`)

- [ ] 3.1 Rewrite `app/views/blocks/_text.html.erb`:
  - Wrap in `<div data-controller="markdown-editor" data-markdown-editor-block-id-value="<%= block.id %>" data-markdown-editor-document-id-value="<%= block.document_id %>">`
  - View mode: `<div data-markdown-editor-target="preview" class="prose max-w-none" data-action="dblclick->markdown-editor#startEditing"><%= render_markdown(block.content_hash["text"]) %></div>`
  - Edit mode (hidden by default): `<div class="hidden" data-markdown-editor-target="editArea">` containing:
    - `<textarea data-markdown-editor-target="textarea" data-action="blur->markdown-editor#saveBlock">` with raw Markdown
    - "Preview" button: `data-action="click->markdown-editor#togglePreview"`
    - "Cancel" button: `data-action="click->markdown-editor#cancelEdit"`

## 4. Stimulus Controller (`markdown_editor_controller.js`)

- [ ] 4.1 Create `app/javascript/controllers/markdown_editor_controller.js` with:
  - `static targets = ["preview", "editArea", "textarea"]`
  - `static values = { blockId: Number, documentId: Number }`
  - `startEditing()` — hide preview, show editArea, focus textarea
  - `cancelEdit()` — hide editArea, show preview (no save)
  - `togglePreview()` — render preview from textarea content (client-side preview via fetch or just show/hide)
  - `saveBlock()` — PATCH to `/api/documents/${this.documentIdValue}/blocks/${this.blockIdValue}` with `{ block: { content: { text: textarea.value } } }`, then reload or re-render
  - `toggleCheckbox(event)` — get checkbox state, update raw Markdown in textarea (toggle `- [ ]` ↔ `- [x]`), call saveBlock()
- [ ] 4.2 Register in `app/javascript/controllers/index.js` (or auto-discovery if using `stimulus-loading`)

## 5. Tailwind Prose Styles

- [ ] 5.1 Check if `@tailwindcss/typography` plugin is installed (`package.json`)
- [ ] 5.2 If not, either:
  - Install: `pnpm add -D @tailwindcss/typography` and add to `tailwind.config.js` plugins
  - Or add minimal `.markdown-body` CSS in `application.tailwind.css` (headings, bold, lists, code blocks)
- [ ] 5.3 Use `class="prose prose-sm max-w-none"` on the preview container

## 6. Block API route

- [ ] 6.1 Verify that `PATCH /api/documents/:document_id/blocks/:id` accepts `block[content][text]`
  - Check `app/controllers/api/blocks_controller.rb` permitted params
  - The `update` action already uses `content_hash` setter — confirm `content` key is permitted

## 7. Verification

- [ ] 7.1 Create a new text document, enter Markdown with `**bold**`, `## heading`, `- [ ] task` → confirm rendered view shows formatted HTML
- [ ] 7.2 Double-click the block → textarea appears with raw Markdown
- [ ] 7.3 Click Preview → shows rendered HTML
- [ ] 7.4 Click Cancel → returns to view mode, no save
- [ ] 7.5 Edit text, click away → block saved, rendered view updated
- [ ] 7.6 Click a `- [ ]` checkbox → toggles to `- [x]`, auto-saves, persists on reload
- [ ] 7.7 Send a voice note via Telegram → transcription text renders as Markdown in the document view
