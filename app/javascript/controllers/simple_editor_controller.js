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
      const { url, filename } = await res.json();

      const markdown = isImage
        ? `![${filename}](${url})`
        : `[${filename}](${url})`;

      this._insertAtCursor(markdown);
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
    return fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        ...this._authHeaders(),
      },
      body: JSON.stringify(body),
    });
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
