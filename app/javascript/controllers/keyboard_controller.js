import { Controller } from "@hotwired/stimulus"

// Handles global keyboard shortcuts (vim-like)
// g + n = new note
// g + s = search
export default class extends Controller {
  connect() {
    console.log("✅ Keyboard controller connected")
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.boundHandleKeydown)
    this.lastKey = null
    this.lastKeyTime = 0
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }

  handleKeydown(event) {
    // Ignore ONLY in form inputs/textareas (not in contenteditable blocks)
    // This allows shortcuts to work in document editor
    if (event.target.matches('input, textarea')) {
      return
    }

    const now = Date.now()
    const key = event.key.toLowerCase()

    // Reset if more than 1 second passed
    if (now - this.lastKeyTime > 1000) {
      this.lastKey = null
    }

    // g + n = new note
    if (this.lastKey === 'g' && key === 'n') {
      event.preventDefault()
      window.location.href = '/new'
      this.lastKey = null
      return
    }

    // g + s = search
    if (this.lastKey === 'g' && key === 's') {
      event.preventDefault()
      const searchButton = document.querySelector('[data-action="click->search#toggleSearch"]')
      const searchInput = document.querySelector('[data-search-target="input"]')
      
      if (searchInput) {
        // If search is hidden, click button to show it
        const searchPopup = document.querySelector('[data-search-target="popup"]')
        if (searchPopup && searchPopup.style.display === 'none') {
          searchButton?.click()
        }
        // Focus input after a small delay
        setTimeout(() => searchInput.focus(), 50)
      }
      this.lastKey = null
      return
    }

    // Track 'g' key
    if (key === 'g') {
      this.lastKey = 'g'
      this.lastKeyTime = now
    }

    // Escape - Close search popup
    if (key === 'escape') {
      const searchPopup = document.querySelector('[data-search-target="popup"]')
      const searchInput = document.querySelector('[data-search-target="input"]')
      
      if (searchPopup && searchPopup.style.display !== 'none') {
        searchPopup.style.display = 'none'
        searchInput.value = ''
      }
    }
  }
}
