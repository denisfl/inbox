import { Controller } from "@hotwired/stimulus"

/**
 * Tag Filter Controller
 *
 * Manages a multi-tag filter bar with:
 * - Active tag pills with × remove buttons
 * - "+ Add tag" button with autocomplete dropdown
 * - Navigation via Turbo.visit() with updated tags[] params
 *
 * Targets:
 *   pills    — container for active tag pills
 *   input    — text input for autocomplete
 *   dropdown — suggestions dropdown
 *   trigger  — "+ Add tag" button
 *   inputWrap — wrapper for input + dropdown (hidden until trigger clicked)
 *
 * Values:
 *   basePath — base URL path (e.g. "/documents", "/tasks", "/tags")
 *   tags     — Array of currently active tag names
 *   preserve — JSON string of extra query params to preserve (e.g. {"filter":"today","sort":"updated_desc"})
 */
export default class extends Controller {
  static targets = ["pills", "input", "dropdown", "trigger", "inputWrap"]
  static values = {
    basePath: String,
    tags: { type: Array, default: [] },
    preserve: { type: String, default: "{}" }
  }

  connect() {
    this._onOutsideClick = this._onOutsideClick.bind(this)
    document.addEventListener("click", this._onOutsideClick)
    this._debounceTimer = null
  }

  disconnect() {
    document.removeEventListener("click", this._onOutsideClick)
    if (this._debounceTimer) clearTimeout(this._debounceTimer)
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /** Remove a tag pill and navigate */
  removeTag(event) {
    const tagName = event.currentTarget.dataset.tagName
    if (!tagName) return

    const updated = this.tagsValue.filter(t => t !== tagName)
    this._navigate(updated)
  }

  /** Show the input field when "+ Add tag" is clicked */
  showInput(event) {
    event.stopPropagation()
    if (this.hasInputWrapTarget) {
      this.inputWrapTarget.style.display = ""
      this.inputTarget.focus()
    }
    if (this.hasTriggerTarget) {
      this.triggerTarget.style.display = "none"
    }
  }

  /** Handle typing in the autocomplete input */
  onInput() {
    const query = this.inputTarget.value.trim()

    if (this._debounceTimer) clearTimeout(this._debounceTimer)

    if (query.length === 0) {
      this._hideDropdown()
      return
    }

    this._debounceTimer = setTimeout(() => {
      this._fetchSuggestions(query)
    }, 200)
  }

  /** Handle keyboard events */
  onKeydown(event) {
    if (event.key === "Escape") {
      this._hideDropdown()
      this._hideInput()
    } else if (event.key === "Enter") {
      event.preventDefault()
      const value = this.inputTarget.value.trim().toLowerCase()
      if (value) this._addTag(value)
    }
  }

  /** Select a suggestion from the dropdown */
  selectSuggestion(event) {
    event.preventDefault()
    event.stopPropagation()
    const tagName = event.currentTarget.dataset.tagName
    if (tagName) this._addTag(tagName)
  }

  // ── Private ──────────────────────────────────────────────────────────────

  _addTag(name) {
    const normalized = name.toLowerCase().trim()
    if (this.tagsValue.includes(normalized)) {
      // Already active — just close
      this._hideDropdown()
      this._hideInput()
      return
    }

    const updated = [...this.tagsValue, normalized]
    this._navigate(updated)
  }

  _navigate(tagNames) {
    const url = new URL(this.basePathValue, window.location.origin)

    // Preserve existing params
    try {
      const preserved = JSON.parse(this.preserveValue)
      for (const [key, val] of Object.entries(preserved)) {
        if (val) url.searchParams.set(key, val)
      }
    } catch { /* ignore parse errors */ }

    // Add tags
    tagNames.forEach(t => url.searchParams.append("tags[]", t))

    if (window.Turbo) {
      Turbo.visit(url.toString())
    } else {
      window.location.href = url.toString()
    }
  }

  async _fetchSuggestions(query) {
    try {
      const resp = await fetch(`/api/tags?q=${encodeURIComponent(query)}`, {
        headers: {
          "Accept": "application/json",
          "Authorization": this._authToken()
        }
      })

      if (!resp.ok) return

      const suggestions = await resp.json()

      // Filter out already-active tags
      const active = new Set(this.tagsValue)
      const filtered = suggestions.filter(s => !active.has(s.name))

      this._renderDropdown(filtered)
    } catch {
      this._hideDropdown()
    }
  }

  _renderDropdown(suggestions) {
    if (!this.hasDropdownTarget) return

    if (suggestions.length === 0) {
      this._hideDropdown()
      return
    }

    this.dropdownTarget.innerHTML = suggestions.map(s => `
      <button type="button" class="tag-filter-dropdown-item"
              data-action="click->tag-filter#selectSuggestion"
              data-tag-name="${this._escapeHtml(s.name)}">
        <span class="tag-color-dot" style="background:${this._escapeHtml(s.color || '#999')}"></span>
        #${this._escapeHtml(s.name)}
      </button>
    `).join("")

    this.dropdownTarget.style.display = "block"
  }

  _hideDropdown() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.style.display = "none"
      this.dropdownTarget.innerHTML = ""
    }
  }

  _hideInput() {
    if (this.hasInputWrapTarget) {
      this.inputWrapTarget.style.display = "none"
      this.inputTarget.value = ""
    }
    if (this.hasTriggerTarget) {
      this.triggerTarget.style.display = ""
    }
  }

  _onOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this._hideDropdown()
      this._hideInput()
    }
  }

  _authToken() {
    const meta = document.querySelector('meta[name="auth-token"]')
    return meta ? `Token token=${meta.content}` : ""
  }

  _escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
