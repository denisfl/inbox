import { Controller } from "@hotwired/stimulus";

// Simple document editor — one Markdown textarea for the whole document.
//
// Features:
//   - Auto-save content with 1 s debounce (PATCH /api/documents/:id/blocks/:blockId)
//   - Editable title with auto-save on blur (PATCH /api/documents/:id)
//   - Preview toggle: textarea ↔ rendered HTML (fetched from server)
//   - Image upload: inserts ![filename](url) at cursor
//   - File upload:  inserts [filename](url) at cursor
//
// All API calls use Authorization: Token token=<meta[name="auth-token"]>.
export default class extends Controller {
  static targets = [
    "textarea",
    "preview",
    "previewToggleBtn",
    "saveIndicator",
    "title",
    "imageInput",
    "fileInput",
  ];
  static values = {
    documentId: Number,
    blockId: Number,
  };

  connect() {
    console.log(
      "✅ simple-editor connected, documentId:",
      this.documentIdValue,
      "blockId:",
      this.blockIdValue,
    );
    this._saveTimer = null;
    this._previewMode = false;
  }

  disconnect() {
    clearTimeout(this._saveTimer);
  }

  // ──────────────────────────────────────────────
  // Auto-save (debounced)
  // ──────────────────────────────────────────────

  scheduleAutoSave() {
    clearTimeout(this._saveTimer);
    this._saveTimer = setTimeout(() => this.saveContent(), 1000);
  }

  async saveContent() {
    const text = this.textareaTarget.value;
    // No text block on this document (e.g. audio-only) — skip save
    if (!this.blockIdValue) return;

    this._showIndicator("saving…", "saving");

    try {
      const res = await this._api(
        `/api/documents/${this.documentIdValue}/blocks/${this.blockIdValue}`,
        "PATCH",
        { block: { content: { text } } },
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      this._showIndicator("saved", "saved");
      // Fade out after 2 s
      setTimeout(() => this._clearIndicator(), 2000);
    } catch (err) {
      console.error("Auto-save failed:", err);
      this._showIndicator("error saving", "error");
    }
  }

  // ──────────────────────────────────────────────
  // Title save
  // ──────────────────────────────────────────────

  async saveTitle() {
    const title = this.titleTarget.textContent.trim();
    if (!title) return;

    try {
      const res = await this._api(
        `/api/documents/${this.documentIdValue}`,
        "PATCH",
        { document: { title } },
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
    } catch (err) {
      console.error("Title save failed:", err);
    }
  }

  // ──────────────────────────────────────────────
  // Preview toggle
  // ──────────────────────────────────────────────

  async togglePreview() {
    this._previewMode = !this._previewMode;

    if (this._previewMode) {
      // Save first so preview shows latest content (only if there's a text block)
      if (this.blockIdValue) {
        clearTimeout(this._saveTimer);
        await this.saveContent();
      }

      // Fetch rendered preview from server (document-level: includes audio + text)
      try {
        const res = await fetch(
          `/api/documents/${this.documentIdValue}/preview`,
          { headers: this._authHeaders() },
        );
        if (res.ok) {
          const { html } = await res.json();
          this.previewTarget.innerHTML = html;
        } else {
          // Fallback: show raw text in <pre>
          this.previewTarget.innerHTML = `<pre>${this._escapeHtml(this.textareaTarget.value)}</pre>`;
        }
      } catch {
        this.previewTarget.innerHTML = `<pre>${this._escapeHtml(this.textareaTarget.value)}</pre>`;
      }

      this.textareaTarget.classList.add("hidden");
      this.previewTarget.classList.remove("hidden");
      this.previewToggleBtnTarget.textContent = "Edit";
    } else {
      this.previewTarget.classList.add("hidden");
      this.textareaTarget.classList.remove("hidden");
      this.textareaTarget.focus();
      this.previewToggleBtnTarget.textContent = "Preview";
    }
  }

  // ──────────────────────────────────────────────
  // File / image upload
  // ──────────────────────────────────────────────

  triggerImageUpload() {
    this.imageInputTarget.click();
  }

  triggerFileUpload() {
    this.fileInputTarget.click();
  }

  async handleImageChange(event) {
    const files = Array.from(event.target.files);
    event.target.value = "";
    for (const file of files) {
      await this._uploadFile(file, true);
    }
  }

  async handleFileChange(event) {
    const files = Array.from(event.target.files);
    event.target.value = "";
    for (const file of files) {
      await this._uploadFile(file, false);
    }
  }

  // ──────────────────────────────────────────────
  // Delete block (attachment)
  // ──────────────────────────────────────────────

  async deleteBlock(event) {
    // Find the delete button — event.target may be SVG/path child of the button
    const button = event.target.closest(".simple-editor-attachment-delete");
    if (!button) return;

    const blockId = button.dataset.blockId;
    if (!blockId) return;

    if (!confirm("Remove this attachment?")) return;

    try {
      const res = await this._api(
        `/api/documents/${this.documentIdValue}/blocks/${blockId}`,
        "DELETE",
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      // Remove the attachment wrapper from the DOM
      const wrapper = button.closest(".simple-editor-attachment");
      if (wrapper) {
        wrapper.style.transition = "opacity 0.2s";
        wrapper.style.opacity = "0";
        setTimeout(() => wrapper.remove(), 200);
      }
    } catch (err) {
      console.error("Delete block failed:", err);
      alert("Failed to delete attachment");
    }
  }

  async _uploadFile(file, isImage) {
    if (!file) return;

    this._showIndicator("uploading…", "saving");

    const formData = new FormData();
    formData.append("file", file);

    try {
      const res = await fetch(`/api/documents/${this.documentIdValue}/upload`, {
        method: "POST",
        headers: this._authHeaders(), // no Content-Type — browser sets multipart boundary
        body: formData,
      });

      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const { url, filename, block_id, byte_size } = data;

      const markdown = isImage
        ? `![${filename}](${url})\n`
        : `[${filename}](${url})\n`;

      this._insertAtCursor(markdown);
      this._addAttachmentToDOM(data);
      this._showIndicator("uploaded", "saved");
      setTimeout(() => this._clearIndicator(), 2000);

      // Trigger auto-save
      this.scheduleAutoSave();
    } catch (err) {
      console.error("Upload failed:", err);
      this._showIndicator("upload failed", "error");
    }
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  _trashIconSVG() {
    return `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" style="width:13px;height:13px"><path stroke-linecap="round" stroke-linejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"/></svg>`;
  }

  _humanSize(bytes) {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1048576).toFixed(1)} MB`;
  }

  _addAttachmentToDOM({ url, filename, is_image, block_id, byte_size }) {
    const body = this.element.querySelector(".simple-editor-body");
    if (!body) return;

    const deleteBtn = `<button type="button" class="simple-editor-attachment-delete" title="Remove" data-action="click->simple-editor#deleteBlock" data-block-id="${block_id}">${this._trashIconSVG()}</button>`;
    const size = this._humanSize(byte_size || 0);

    let sectionClass, html;

    if (is_image) {
      sectionClass = "simple-editor-images-section";
      html = `
        <div class="simple-editor-attachment" data-block-id="${block_id}">
          <div class="simple-editor-image-wrapper">
            <img src="${url}" alt="${this._escapeHtml(filename)}" class="simple-editor-image-preview">
            <div class="simple-editor-image-filename">📷 ${this._escapeHtml(filename)} · ${size}</div>
          </div>
          ${deleteBtn}
        </div>`;
    } else {
      sectionClass = "simple-editor-files-section";
      html = `
        <div class="simple-editor-attachment" data-block-id="${block_id}">
          <div class="simple-editor-file-info">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" style="width:16px;height:16px;color:var(--color-text-tertiary);flex-shrink:0"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z"/></svg>
            <a href="${url}" target="_blank" class="simple-editor-file-link">${this._escapeHtml(filename)}</a>
            <span class="simple-editor-file-size">${size}</span>
          </div>
          ${deleteBtn}
        </div>`;
    }

    // Find or create the section container
    let section = body.querySelector(`.${sectionClass}`);
    if (!section) {
      section = document.createElement("div");
      section.className = sectionClass;
      // Insert before textarea
      const textarea = body.querySelector(".simple-editor-textarea");
      if (textarea) {
        body.insertBefore(section, textarea);
      } else {
        body.appendChild(section);
      }
    }

    section.insertAdjacentHTML("beforeend", html);
  }

  _insertAtCursor(text) {
    const ta = this.textareaTarget;
    const start = ta.selectionStart;
    const end = ta.selectionEnd;
    ta.value = ta.value.slice(0, start) + text + ta.value.slice(end);
    ta.selectionStart = ta.selectionEnd = start + text.length;
    ta.focus();
  }

  _authHeaders() {
    const token = document.querySelector('meta[name="auth-token"]')?.content;
    return { Authorization: `Token token=${token}` };
  }

  async _api(url, method, body) {
    const options = {
      method,
      headers: { ...this._authHeaders() },
    };
    if (body !== undefined) {
      options.headers["Content-Type"] = "application/json";
      options.body = JSON.stringify(body);
    }
    return fetch(url, options);
  }

  _showIndicator(message, state) {
    if (!this.hasSaveIndicatorTarget) return;
    const el = this.saveIndicatorTarget;
    el.textContent = message;
    el.className = `save-indicator save-indicator--${state}`;
  }

  _clearIndicator() {
    if (!this.hasSaveIndicatorTarget) return;
    this.saveIndicatorTarget.textContent = "";
    this.saveIndicatorTarget.className = "save-indicator";
  }

  _escapeHtml(text) {
    return text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }
}
