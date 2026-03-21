import { Controller } from "@hotwired/stimulus";

// Wiki-link autocomplete controller for the document editor.
// Detects `[[` input in the Lexxy rich text editor and shows a dropdown
// with document title suggestions fetched from /documents/search.json.
export default class extends Controller {
  static values = { url: { type: String, default: "/documents/search.json" } };

  connect() {
    this._dropdown = null;
    this._selectedIndex = -1;
    this._results = [];
    this._active = false;
    this._inserting = false;
    this._query = "";
    this._debounceTimer = null;
    this._initObserver = null;

    this._tryAttach();
  }

  _tryAttach() {
    this._editor = this.element.querySelector(".lexxy-editor__content") ||
                   this.element.querySelector("[contenteditable]");

    if (this._editor) {
      this._bind();
      return;
    }

    // Lexxy custom element may not have rendered its content div yet.
    // Watch for it to appear.
    const lexxy = this.element.querySelector("lexxy-editor");
    if (!lexxy) return;

    this._initObserver = new MutationObserver(() => {
      this._editor = lexxy.querySelector(".lexxy-editor__content");
      if (this._editor) {
        this._initObserver.disconnect();
        this._initObserver = null;
        this._bind();
      }
    });
    this._initObserver.observe(lexxy, { childList: true });
  }

  _bind() {
    this._onInput = this._handleInput.bind(this);
    this._onKeyDown = this._handleKeyDown.bind(this);
    this._onClickOutside = this._handleClickOutside.bind(this);

    this._editor.addEventListener("input", this._onInput);
    this._editor.addEventListener("keydown", this._onKeyDown, true);
    document.addEventListener("click", this._onClickOutside);
  }

  disconnect() {
    if (this._initObserver) {
      this._initObserver.disconnect();
      this._initObserver = null;
    }
    if (this._editor) {
      this._editor.removeEventListener("input", this._onInput);
      this._editor.removeEventListener("keydown", this._onKeyDown, true);
    }
    document.removeEventListener("click", this._onClickOutside);
    this._close();
  }

  // ── Input Detection ──

  _handleInput() {
    if (this._inserting) return;

    const context = this._getTextBeforeCursor();
    if (!context) {
      this._close();
      return;
    }

    // Match [[ followed by optional query text (no ] allowed)
    const match = context.match(/\[\[([^\]]{0,100})$/);
    if (match) {
      this._active = true;
      this._query = match[1];
      this._debouncedSearch(this._query);
    } else if (this._active) {
      this._close();
    }
  }

  _getTextBeforeCursor() {
    const sel = window.getSelection();
    if (!sel || sel.rangeCount === 0) return null;

    const range = sel.getRangeAt(0);
    if (!this._editor.contains(range.startContainer)) return null;

    // Get text content from the current text node up to the cursor
    const node = range.startContainer;
    if (node.nodeType !== Node.TEXT_NODE) return null;

    return node.textContent.slice(0, range.startOffset);
  }

  // ── Search ──

  _debouncedSearch(query) {
    clearTimeout(this._debounceTimer);
    this._debounceTimer = setTimeout(() => this._search(query), 200);
  }

  async _search(query) {
    const url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set("q", query);

    try {
      const response = await fetch(url.toString(), {
        headers: { "Accept": "application/json" }
      });
      if (!response.ok) return;

      this._results = await response.json();
      this._selectedIndex = -1;
      this._renderDropdown();
    } catch {
      // Silently fail on network errors
    }
  }

  // ── Dropdown Rendering ──

  _renderDropdown() {
    if (!this._results.length) {
      this._close();
      return;
    }

    if (!this._dropdown) {
      this._dropdown = document.createElement("div");
      this._dropdown.className = "wiki-link-dropdown";
      document.body.appendChild(this._dropdown);
    }

    this._dropdown.innerHTML = this._results
      .map((doc, i) => {
        const cls = i === this._selectedIndex ? "wiki-link-dropdown__item wiki-link-dropdown__item--active" : "wiki-link-dropdown__item";
        return `<div class="${cls}" data-index="${i}" data-id="${doc.id}" data-title="${this._escapeAttr(doc.title)}">${this._escapeHtml(doc.title)}</div>`;
      })
      .join("");

    // Position below cursor
    this._positionDropdown();

    // Bind click events
    this._dropdown.querySelectorAll(".wiki-link-dropdown__item").forEach((item) => {
      item.addEventListener("mousedown", (e) => {
        e.preventDefault();
        this._selectItem(parseInt(item.dataset.index, 10));
      });
    });

    this._dropdown.style.display = "block";
  }

  _positionDropdown() {
    const sel = window.getSelection();
    if (!sel || sel.rangeCount === 0) return;

    const range = sel.getRangeAt(0);
    const rect = range.getBoundingClientRect();

    this._dropdown.style.position = "fixed";
    this._dropdown.style.top = `${rect.bottom + 4}px`;
    this._dropdown.style.left = `${rect.left}px`;
    this._dropdown.style.zIndex = "10000";
  }

  // ── Keyboard Navigation ──

  _handleKeyDown(e) {
    if (!this._active || !this._dropdown) return;

    switch (e.key) {
      case "ArrowDown":
        e.preventDefault();
        this._selectedIndex = Math.min(this._selectedIndex + 1, this._results.length - 1);
        this._updateActiveItem();
        break;
      case "ArrowUp":
        e.preventDefault();
        this._selectedIndex = Math.max(this._selectedIndex - 1, 0);
        this._updateActiveItem();
        break;
      case "Enter":
        if (this._selectedIndex >= 0) {
          e.preventDefault();
          this._selectItem(this._selectedIndex);
        }
        break;
      case "Escape":
        e.preventDefault();
        this._close();
        break;
    }
  }

  _updateActiveItem() {
    if (!this._dropdown) return;
    this._dropdown.querySelectorAll(".wiki-link-dropdown__item").forEach((item, i) => {
      item.classList.toggle("wiki-link-dropdown__item--active", i === this._selectedIndex);
    });

    // Scroll active item into view
    const activeItem = this._dropdown.querySelector(".wiki-link-dropdown__item--active");
    if (activeItem) activeItem.scrollIntoView({ block: "nearest" });
  }

  // ── Selection & Insertion ──

  _selectItem(index) {
    const doc = this._results[index];
    if (!doc) return;

    this._insertWikiLink(doc.title);
    this._close();
  }

  _insertWikiLink(title) {
    this._inserting = true;

    const sel = window.getSelection();
    if (!sel || sel.rangeCount === 0) { this._inserting = false; return; }

    const range = sel.getRangeAt(0);
    const node = range.startContainer;
    if (node.nodeType !== Node.TEXT_NODE) { this._inserting = false; return; }

    const offset = range.startOffset;
    const text = node.textContent;

    // Find the [[ that started this autocomplete
    const before = text.slice(0, offset);
    const bracketPos = before.lastIndexOf("[[");
    if (bracketPos === -1) { this._inserting = false; return; }

    // Select from [[ to cursor position, then replace via execCommand
    // so ProseMirror (Lexxy) processes it as a normal text input
    range.setStart(node, bracketPos);
    range.setEnd(node, offset);
    sel.removeAllRanges();
    sel.addRange(range);

    const replacement = `[[${title}]] `;
    document.execCommand("insertText", false, replacement);

    this._inserting = false;
  }

  // ── Close & Cleanup ──

  _close() {
    this._active = false;
    this._results = [];
    this._selectedIndex = -1;
    clearTimeout(this._debounceTimer);

    if (this._dropdown) {
      this._dropdown.remove();
      this._dropdown = null;
    }
  }

  _handleClickOutside(e) {
    if (this._dropdown && !this._dropdown.contains(e.target)) {
      this._close();
    }
  }

  // ── Utilities ──

  _escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  _escapeAttr(text) {
    return text.replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }
}
