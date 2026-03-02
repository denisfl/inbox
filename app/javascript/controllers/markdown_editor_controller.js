import { Controller } from "@hotwired/stimulus";

// Markdown editor controller for text blocks.
// - View mode: rendered HTML + inline Edit button
// - Edit mode: raw Markdown textarea — ⌘↵/Save button to save, Esc/Cancel to discard
// - Checkbox toggling: click updates Markdown source and auto-saves
export default class extends Controller {
  static targets = ["preview", "editArea", "textarea", "renderedContent"];
  static values = { blockId: Number, documentId: Number };

  connect() {
    console.log("✅ markdown-editor connected, blockId:", this.blockIdValue);
    // If block content is empty, go straight to edit mode on mount
    const content = this.hasRenderedContentTarget
      ? this.renderedContentTarget.textContent.trim()
      : this.hasTextareaTarget
        ? this.textareaTarget.value.trim()
        : "";
    if (!content) {
      this.startEditing();
    }
  }

  // ──────────────────────────────────────────────
  // Edit mode toggle
  // ──────────────────────────────────────────────

  startEditing() {
    this.previewTarget.classList.add("hidden");
    this.editAreaTarget.classList.remove("hidden");
    this.textareaTarget.focus();
    // Place cursor at end
    const len = this.textareaTarget.value.length;
    this.textareaTarget.setSelectionRange(len, len);
  }

  cancelEdit() {
    this.editAreaTarget.classList.add("hidden");
    this.previewTarget.classList.remove("hidden");
  }

  // Keyboard shortcuts inside textarea: ⌘↵ save, Esc cancel
  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      this.saveBlock();
    }
    if (event.key === "Escape") {
      event.preventDefault();
      this.cancelEdit();
    }
  }

  // ──────────────────────────────────────────────
  // Save
  // ──────────────────────────────────────────────

  async saveBlock() {
    const text = this.textareaTarget.value;
    const authToken = document.querySelector(
      'meta[name="auth-token"]',
    )?.content;

    try {
      const response = await fetch(
        `/api/documents/${this.documentIdValue}/blocks/${this.blockIdValue}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Token token=${authToken}`,
          },
          body: JSON.stringify({ block: { content: { text } } }),
        },
      );

      if (!response.ok) {
        console.error("Failed to save block:", response.status);
        return;
      }

      // Re-render via Turbo frame / full page reload to show updated Markdown
      const frame = this.element.closest("turbo-frame");
      if (frame) {
        frame.reload();
      } else {
        window.location.reload();
      }
    } catch (err) {
      console.error("Save error:", err);
    }
  }

  // ──────────────────────────────────────────────
  // Checkbox toggling (task lists)
  // ──────────────────────────────────────────────

  toggleCheckbox(event) {
    const checkbox = event.currentTarget;
    const nowChecked = checkbox.checked;
    const li = checkbox.closest("li");
    if (!li) return;

    // Extract visible label text (excluding nested lists)
    const clone = li.cloneNode(true);
    clone.querySelectorAll("ul, ol").forEach((el) => el.remove());
    const labelText = clone.textContent.trim();
    if (!labelText) return;

    const escaped = labelText.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

    // Toggle in raw Markdown source
    let text = this.textareaTarget.value;
    if (nowChecked) {
      text = text.replace(
        new RegExp(`(- \\[ \\] )(${escaped})`, "m"),
        `- [x] $2`,
      );
    } else {
      text = text.replace(
        new RegExp(`(- \\[x\\] )(${escaped})`, "im"),
        `- [ ] $2`,
      );
    }
    this.textareaTarget.value = text;
    this.saveBlock();
  }
}
