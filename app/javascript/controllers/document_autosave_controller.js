import { Controller } from "@hotwired/stimulus";

// Auto-saves the document body form on content changes with a 1s debounce.
// Shows a save indicator in the header (saving → saved → fade out).
export default class extends Controller {
  static targets = ["form", "indicator"];

  connect() {
    this._saveTimer = null;
    this._listenForChanges();
  }

  disconnect() {
    clearTimeout(this._saveTimer);
    if (this._observer) {
      this._observer.disconnect();
    }
  }

  _listenForChanges() {
    // Lexxy editor fires input events on the content area
    const form = this.formTarget;
    form.addEventListener("input", () => this._scheduleAutoSave());

    // Also observe mutations for programmatic changes (e.g. toolbar actions)
    const editor = form.querySelector("lexxy-editor");
    if (editor) {
      this._observer = new MutationObserver(() => this._scheduleAutoSave());
      this._observer.observe(editor, {
        childList: true,
        subtree: true,
        characterData: true,
      });
    }
  }

  _scheduleAutoSave() {
    clearTimeout(this._saveTimer);
    this._saveTimer = setTimeout(() => this._save(), 1000);
  }

  async _save() {
    const form = this.formTarget;
    this._showIndicator("saving…", "saving");

    try {
      const formData = new FormData(form);
      const res = await fetch(form.action, {
        method: "PATCH",
        body: formData,
        headers: {
          Accept:
            "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            ?.content,
        },
      });

      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      this._showIndicator("saved", "saved");
      setTimeout(() => this._clearIndicator(), 2000);
    } catch (err) {
      console.error("Auto-save failed:", err);
      this._showIndicator("error saving", "error");
    }
  }

  _showIndicator(message, state) {
    if (!this.hasIndicatorTarget) return;
    const el = this.indicatorTarget;
    el.textContent = message;
    el.className = `save-indicator save-indicator--${state}`;
  }

  _clearIndicator() {
    if (!this.hasIndicatorTarget) return;
    this.indicatorTarget.textContent = "";
    this.indicatorTarget.className = "save-indicator";
  }
}
