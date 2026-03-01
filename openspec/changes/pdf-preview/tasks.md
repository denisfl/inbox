---
id: pdf-preview
artifact: tasks
---

## Tasks

### 1. File Block Partial — PDF branch

- [ ] Open `app/views/blocks/_file.html.erb`
- [ ] Add PDF content-type detection: `block.file.content_type == 'application/pdf'`
- [ ] Insert PDF branch between audio branch and generic file branch
- [ ] Render `<iframe>` with `rails_blob_path(block.file)` as `src`
- [ ] Add header row with filename icon, truncated name, file size
- [ ] Add action row: "Download" link (`disposition: "attachment"`) + "Open in new tab" link

```erb
<% is_pdf = block.file.content_type == 'application/pdf' %>
<% if is_audio %>
  <%# ... existing audio player ... %>
<% elsif is_pdf %>
  <div class="pdf-viewer">
    <div class="pdf-viewer-header">
      <%= heroicon(:document_text, style: "width:16px;height:16px;color:var(--color-text-tertiary)") %>
      <span><%= block.file.filename.to_s.truncate(50) %></span>
      <span class="file-size"><%= number_to_human_size(block.file.byte_size) %></span>
    </div>
    <iframe src="<%= rails_blob_path(block.file) %>"
            class="pdf-viewer-frame"
            title="<%= block.file.filename %>">
    </iframe>
    <div class="pdf-viewer-actions">
      <%= link_to "Download", rails_blob_path(block.file, disposition: "attachment"), download: block.file.filename %>
      <%= link_to "Open in new tab", rails_blob_path(block.file), target: "_blank" %>
    </div>
  </div>
<% else %>
  <%# ... existing generic file link ... %>
<% end %>
```

### 2. API Preview Endpoint — PDF embed

- [ ] Open `app/controllers/api/documents_controller.rb`
- [ ] In `preview` action, after audio HTML block, add PDF detection loop
- [ ] For each file block with `content_type == 'application/pdf'`, generate `<iframe>` HTML
- [ ] Prepend/append PDF HTML to the combined response: `audio_html + pdf_html + text_html`

```ruby
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

### 3. Edit Page — Inline PDF section

- [ ] Open `app/views/documents/edit.html.erb`
- [ ] After the audio section, before the textarea, add PDF viewer section
- [ ] Filter blocks: `block_type == "file"` + file attached + `content_type == "application/pdf"`
- [ ] Render each PDF block as `<iframe>` with filename label below

### 4. CSS Styles

- [ ] Add PDF viewer styles to `app/assets/stylesheets/application.css` or a new `pdf.css`
- [ ] `.pdf-viewer`, `.pdf-viewer-header`, `.pdf-viewer-frame`, `.pdf-viewer-actions`
- [ ] `.simple-editor-pdf-section`, `.simple-editor-pdf-frame`, `.simple-editor-pdf-filename`
- [ ] Mobile media query: reduce iframe height to `40vh` at `max-width: 768px`
- [ ] If new CSS file created, register in `app/views/layouts/application.html.erb` stylesheet_link_tag

### 5. Content Security Policy

- [ ] Verify `frame-src 'self'` allows Active Storage blob iframes
- [ ] If needed, update `config/initializers/content_security_policy.rb`

### 6. Manual Testing

- [ ] Upload a PDF file to a document
- [ ] Verify PDF renders inline in the file block on document show page
- [ ] Verify PDF renders inline on document edit page
- [ ] Verify API preview endpoint returns PDF iframe HTML
- [ ] Test "Download" button — triggers file download
- [ ] Test "Open in new tab" — opens PDF in new browser tab
- [ ] Test on mobile viewport — iframe height reduced, still usable
- [ ] Test non-PDF files — should still render as before (icon + link)
- [ ] Test document with both audio and PDF blocks — both render correctly
