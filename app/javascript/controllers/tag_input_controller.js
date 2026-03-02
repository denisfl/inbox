import { Controller } from "@hotwired/stimulus"

/**
 * Tag input controller — add/remove tags with autocomplete.
 *
 * Usage:
 *   <div data-controller="tag-input"
 *        data-tag-input-entity-type-value="document"
 *        data-tag-input-entity-id-value="123">
 *
 * Values:
 *   entityType — "document", "task", or "calendar_event"
 *   entityId   — the record id
 *
 * Targets:
 *   input      — the text input for typing new tag names
 *   pills      — container for tag pill elements
 *   dropdown   — autocomplete suggestion dropdown
 */
export default class extends Controller {
  static targets = ["input", "pills", "dropdown"]
  static values  = { entityType: String, entityId: Number }

  connect() {
    this._debounceTimer = null
    // Close dropdown on outside click
    this._onOutsideClick = (e) => {
      if (!this.element.contains(e.target)) this._hideDropdown()
    }
    document.addEventListener("click", this._onOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this._onOutsideClick)
    if (this._debounceTimer) clearTimeout(this._debounceTimer)
  }

  // ── Input events ──────────────────────────────────────────────────────

  onInput() {
    const q = this.inputTarget.value.trim()
    if (q.length === 0) {
      this._hideDropdown()
      return
    }
    // Debounce autocomplete
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this._fetchSuggestions(q), 200)
  }

  onKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      const name = this.inputTarget.value.trim().toLowerCase().replace(/[^a-z0-9а-яё_-]/gi, "")
      if (name.length > 0) {
        this._addTag(name)
        this.inputTarget.value = ""
        this._hideDropdown()
      }
    }
    if (event.key === "Escape") {
      this._hideDropdown()
    }
  }

  // ── Tag operations ────────────────────────────────────────────────────

  async _addTag(name) {
    // Don't add if already present
    if (this._currentTags().includes(name)) return

    try {
      const res = await this._api("POST", this._tagsUrl(), { name })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const data = await res.json()

      this._appendPill(data.tag.name, data.tag.color)
    } catch (err) {
      console.error("Failed to add tag:", err)
    }
  }

  async removeTag(event) {
    const pill = event.target.closest(".tag-pill")
    if (!pill) return

    const name = pill.dataset.tagName
    try {
      const res = await this._api("DELETE", `${this._tagsUrl()}/${encodeURIComponent(name)}`)
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      pill.remove()
    } catch (err) {
      console.error("Failed to remove tag:", err)
    }
  }

  selectSuggestion(event) {
    const item = event.target.closest("[data-tag-name]")
    if (!item) return

    const name = item.dataset.tagName
    this._addTag(name)
    this.inputTarget.value = ""
    this._hideDropdown()
  }

  // ── Autocomplete ──────────────────────────────────────────────────────

  async _fetchSuggestions(q) {
    try {
      const res = await this._api("GET", `/api/tags?q=${encodeURIComponent(q)}`)
      if (!res.ok) return
      const tags = await res.json()

      const existing = this._currentTags()
      const filtered = tags.filter(t => !existing.includes(t.name))

      if (filtered.length === 0) {
        this._hideDropdown()
        return
      }

      this.dropdownTarget.innerHTML = filtered.map(t =>
        `<div class="tag-dropdown-item" data-tag-name="${t.name}" data-action="click->tag-input#selectSuggestion">
          <span class="tag-color-dot" style="background:${t.color || 'var(--color-text-tertiary)'}"></span>
          #${t.name}
        </div>`
      ).join("")
      this.dropdownTarget.classList.remove("hidden")
    } catch (err) {
      console.error("Autocomplete error:", err)
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  _tagsUrl() {
    const type = this.entityTypeValue
    const id   = this.entityIdValue
    if (type === "document")       return `/api/documents/${id}/tags`
    if (type === "task")           return `/api/tasks/${id}/tags`
    if (type === "calendar_event") return `/api/calendar_events/${id}/tags`
    throw new Error(`Unknown entity type: ${type}`)
  }

  _api(method, url, body) {
    const token = document.querySelector('meta[name="auth-token"]')?.content
    const opts = {
      method,
      headers: { "Authorization": `Token token=${token}` }
    }
    if (body !== undefined) {
      opts.headers["Content-Type"] = "application/json"
      opts.body = JSON.stringify(body)
    }
    return fetch(url, opts)
  }

  _currentTags() {
    return Array.from(this.pillsTarget.querySelectorAll(".tag-pill"))
      .map(el => el.dataset.tagName)
  }

  _appendPill(name, color) {
    const pill = document.createElement("span")
    pill.className = "tag-pill"
    pill.dataset.tagName = name
    pill.innerHTML = `
      <span class="tag-pill-dot" style="background:${color || 'var(--color-text-tertiary)'}"></span>
      #${name}
      <button type="button" class="tag-pill-remove" data-action="click->tag-input#removeTag">&times;</button>
    `
    this.pillsTarget.appendChild(pill)
  }

  _hideDropdown() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.add("hidden")
    }
  }
}
