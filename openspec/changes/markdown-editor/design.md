# Design: Markdown Editor for Text Blocks

## Architecture

```
Block content["text"]  →  Raw Markdown string (stored in DB)
       ↓ view mode
MarkdownHelper#render_markdown(text)  →  Sanitized HTML
       ↓
app/views/blocks/_text.html.erb  →  Rendered in <div class="markdown-body">
       ↓ interactive checkboxes
markdown_editor_controller.js  →  toggle checkbox → PATCH /api/blocks/:id
```

```
Edit mode:
<textarea class="markdown-textarea">## Markdown</textarea>
[Preview] button → toggle → <div class="markdown-preview">{rendered HTML}</div>
```

---

## Gem: Redcarpet

```ruby
# Gemfile
gem "redcarpet"
```

Renderer configuration:

```ruby
# app/helpers/application_helper.rb (or markdown_helper.rb)
def render_markdown(text)
  return "" if text.blank?

  renderer = Redcarpet::Render::HTML.new(
    hard_wrap: true,
    link_attributes: { target: "_blank", rel: "noopener" },
    with_toc_data: false
  )
  markdown = Redcarpet::Markdown.new(
    renderer,
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    strikethrough: true,
    lax_spacing: true,
    space_after_headers: false,
    superscript: false,
    underline: false,
    highlight: false,
    quote: false,
    no_intra_emphasis: true
  )
  markdown.render(text).html_safe
end
```

---

## Text Block View (`_text.html.erb`)

```erb
<div class="text-block"
     data-controller="markdown-editor"
     data-markdown-editor-block-id-value="<%= block.id %>">

  <%# View mode — rendered Markdown %>
  <div class="markdown-body prose"
       data-markdown-editor-target="preview"
       data-action="dblclick->markdown-editor#startEditing">
    <%= render_markdown(block.content_hash["text"]) %>
  </div>

  <%# Edit mode — hidden by default %>
  <div class="markdown-edit hidden" data-markdown-editor-target="editArea">
    <textarea class="markdown-textarea w-full min-h-[120px] font-mono text-sm p-2 border rounded"
              data-markdown-editor-target="textarea"
              data-action="blur->markdown-editor#saveBlock">
<%= block.content_hash["text"] %></textarea>
    <div class="flex gap-2 mt-1">
      <button type="button" class="text-xs text-blue-500 hover:underline"
              data-action="click->markdown-editor#togglePreview">
        Preview
      </button>
      <button type="button" class="text-xs text-gray-400 hover:underline"
              data-action="click->markdown-editor#cancelEdit">
        Cancel
      </button>
    </div>
  </div>
</div>
```

---

## Stimulus Controller (`markdown_editor_controller.js`)

```javascript
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["preview", "editArea", "textarea"];
  static values = { blockId: Number };

  startEditing() {
    this.previewTarget.classList.add("hidden");
    this.editAreaTarget.classList.remove("hidden");
    this.textareaTarget.focus();
  }

  cancelEdit() {
    this.editAreaTarget.classList.add("hidden");
    this.previewTarget.classList.remove("hidden");
  }

  async saveBlock() {
    const text = this.textareaTarget.value;
    await fetch(`/api/blocks/${this.blockIdValue}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
      body: JSON.stringify({ block: { content: { text } } }),
    });
    // Re-render preview by reloading the turbo frame or doing a full replace
    this.cancelEdit();
    // Reload the page section to show rendered Markdown
    window.location.reload();
  }

  toggleCheckbox(event) {
    const checkbox = event.currentTarget;
    const checked = checkbox.checked;
    const itemText = checkbox.nextElementSibling?.textContent?.trim();
    if (!itemText) return;

    let text = this.currentText();
    // Toggle - [ ] <-> - [x] for the matching line
    const pattern = checked ? new RegExp(`- \\[ \\] (${escapeRegex(itemText)})`) : new RegExp(`- \\[x\\] (${escapeRegex(itemText)})`, "i");
    const replacement = checked ? "- [x] $1" : "- [ ] $1";
    const newText = text.replace(pattern, replacement);

    this.textareaTarget.value = newText;
    this.saveBlock();
  }

  currentText() {
    return this.textareaTarget.value || this.previewTarget.dataset.rawText || "";
  }
}

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
```

---

## Interactive Checkboxes

Redcarpet renders `- [ ]` as `<input type="checkbox" disabled>`. To make them interactive, override the rendered HTML:

Option 1 — Custom Redcarpet renderer:

```ruby
class InboxMarkdownRenderer < Redcarpet::Render::HTML
  def list_item(text, _list_type)
    if text.start_with?("[x]", "[X]")
      body = text.sub(/^\[x\]\s*/i, "")
      "<li><label><input type='checkbox' checked data-action='change->markdown-editor#toggleCheckbox'> #{body}</label></li>\n"
    elsif text.start_with?("[ ]")
      body = text.sub(/^\[ \]\s*/, "")
      "<li><label><input type='checkbox' data-action='change->markdown-editor#toggleCheckbox'> #{body}</label></li>\n"
    else
      "<li>#{text}</li>\n"
    end
  end
end
```

Option 2 — Post-process via regex replace (simpler, no subclassing):

```ruby
def render_markdown(text)
  html = markdown_engine.render(text)
  html = html.gsub(/<input type="checkbox" disabled="">/, '<input type="checkbox" data-action="change->markdown-editor#toggleCheckbox">')
  html = html.gsub(/<input type="checkbox" disabled="" checked="">/, '<input type="checkbox" checked data-action="change->markdown-editor#toggleCheckbox">')
  html.html_safe
end
```

**Use Option 2** — Redcarpet with `:footnotes` disabled renders task lists as checkboxes with `disabled` attribute; we just strip `disabled`.

---

## Tailwind Prose Plugin

Use `@tailwindcss/typography` for styled Markdown output:

```html
<div class="prose prose-sm max-w-none dark:prose-invert">
  <!-- rendered markdown -->
</div>
```

Or define custom `.markdown-body` styles if Tailwind typography plugin isn't installed.

---

## API: Block Update

The existing `PATCH /api/blocks/:id` endpoint is already available. Confirm it accepts `content[text]`.

Check `app/controllers/api/blocks_controller.rb` for permitted params.

---

## Backward Compatibility

All existing plain text content renders as valid Markdown (plain text IS valid Markdown). No migration needed. The only visible change: blank lines between paragraphs will render as separate `<p>` tags instead of raw newlines.
