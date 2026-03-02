---
id: pdf-preview
artifact: design
---

## Architecture

### Detection Flow

```
Document has file blocks
  → block.file.content_type == "application/pdf"?
    → YES: render PDF viewer (iframe)
    → NO:  existing logic (audio player / download link)
```

### Rendering Strategy

Use the browser's native PDF renderer via `<iframe>` pointing to the Active Storage blob URL. This approach:

- Zero dependencies (no PDF.js, no gems)
- Works in all desktop browsers
- Graceful fallback to download link on unsupported environments

### Components

#### 1. File Block Partial (`_file.html.erb`)

Add a third branch (alongside audio and generic file):

```erb
<% is_pdf = block.file.content_type == 'application/pdf' %>
<% if is_audio %>
  <%# existing audio player %>
<% elsif is_pdf %>
  <%# PDF inline viewer %>
  <div class="pdf-viewer">
    <div class="pdf-viewer-header">
      <span class="pdf-viewer-filename">
        <%= heroicon(:document_text, style: '...') %>
        <%= block.file.filename.to_s.truncate(50) %>
      </span>
      <span class="file-size"><%= number_to_human_size(block.file.byte_size) %></span>
    </div>
    <iframe src="<%= rails_blob_path(block.file) %>"
            class="pdf-viewer-frame"
            title="<%= block.file.filename %>">
    </iframe>
    <div class="pdf-viewer-actions">
      <%= link_to "Download", rails_blob_path(block.file, disposition: "attachment"),
            class: "btn btn-sm btn-secondary", download: block.file.filename %>
      <%= link_to "Open in new tab", rails_blob_path(block.file),
            class: "btn btn-sm btn-secondary", target: "_blank" %>
    </div>
  </div>
<% else %>
  <%# existing generic file link %>
<% end %>
```

#### 2. Simple Editor Preview (API)

In `api/documents_controller.rb#preview`, after `audio_html` and before `text_html`:

```ruby
# PDF blocks
pdf_html = ""
@document.blocks.where(block_type: "file").each do |b|
  next unless b.file.attached? && b.file.content_type == "application/pdf"
  pdf_url = url_for(b.file)
  filename = ERB::Util.html_escape(b.file.filename.to_s)
  pdf_html += <<~HTML
    <div class="pdf-preview-embed">
      <iframe src="#{pdf_url}" style="width:100%;height:600px;border:1px solid var(--color-border);border-radius:var(--radius-base);" title="#{filename}"></iframe>
      <div style="margin-top:8px;font-size:12px;color:var(--color-text-tertiary)">📄 #{filename}</div>
    </div>
  HTML
end

render json: { html: audio_html + pdf_html + text_html }
```

#### 3. Edit Page (Inline PDF Section)

In `documents/edit.html.erb`, between the audio section and the textarea, add:

```erb
<%# ── PDF viewers ── %>
<% pdf_blocks = @blocks.select { |b| b.block_type == "file" && b.file.attached? && b.file.content_type == "application/pdf" } %>
<% if pdf_blocks.any? %>
  <div class="simple-editor-pdf-section">
    <% pdf_blocks.each do |pb| %>
      <div class="simple-editor-pdf-viewer">
        <iframe src="<%= url_for(pb.file) %>"
                class="simple-editor-pdf-frame"
                title="<%= pb.file.filename %>">
        </iframe>
        <div class="simple-editor-pdf-filename">
          📄 <%= pb.file.filename %> · <%= number_to_human_size(pb.file.byte_size) %>
        </div>
      </div>
    <% end %>
  </div>
<% end %>
```

### CSS

```css
/* PDF viewer in file block partial */
.pdf-viewer { margin-top: var(--spacing-sm); }
.pdf-viewer-header {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  margin-bottom: var(--spacing-sm);
}
.pdf-viewer-frame {
  width: 100%;
  height: 70vh;
  max-height: 800px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-base);
}
.pdf-viewer-actions {
  display: flex;
  gap: var(--spacing-sm);
  margin-top: var(--spacing-sm);
}

/* PDF in simple editor */
.simple-editor-pdf-section {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
}
.simple-editor-pdf-frame {
  width: 100%;
  height: 60vh;
  max-height: 700px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-base);
}
.simple-editor-pdf-filename {
  font-size: var(--text-xs);
  color: var(--color-text-tertiary);
  margin-top: var(--spacing-xs);
}

/* Mobile: shorter iframe */
@media (max-width: 768px) {
  .pdf-viewer-frame,
  .simple-editor-pdf-frame {
    height: 40vh;
    max-height: 400px;
  }
}
```

### Content Security Policy

The current CSP in `config/initializers/content_security_policy.rb` may need an update to allow `frame-src` for Active Storage blob URLs. Since blobs are served from the same origin (`/rails/active_storage/blobs/...`), this should work by default with `'self'`.

### Mobile Fallback

On mobile browsers that don't support inline PDF rendering (rare in 2025), the `<iframe>` will show the browser's default download prompt. The explicit "Download" and "Open in new tab" buttons below the viewer provide a reliable fallback.
