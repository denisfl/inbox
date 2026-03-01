import { Controller } from "@hotwired/stimulus"

// Handles inline task toggling on the dashboard.
// Sends PATCH request via XHR, then visually marks the item as done.
export default class extends Controller {
  static values = { url: String }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    const item = this.element
    const url = item.dataset.taskToggleUrlValue

    if (!url) return

    const csrfMeta = document.querySelector('meta[name="csrf-token"]')
    const csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : ""

    const xhr = new XMLHttpRequest()
    xhr.open("PATCH", url, true)
    xhr.setRequestHeader("X-CSRF-Token", csrfToken)
    xhr.setRequestHeader("Accept", "application/json, text/plain")

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 400) {
        item.style.opacity = "0.5"

        const checkbox = item.querySelector(".task-check")
        if (checkbox) {
          checkbox.classList.add("done")
          checkbox.innerHTML = '<svg width="8" height="8" viewBox="0 0 8 8" fill="none"><path d="M1.5 4l2 2 3-3" stroke="white" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
        }

        const title = item.querySelector(".task-title")
        if (title) title.classList.add("done")

        const due = item.querySelector(".task-due")
        if (due) {
          due.classList.remove("overdue")
          due.textContent = "done"
        }

        const btn = item.querySelector(".task-toggle-btn")
        if (btn) btn.disabled = true
      }
    }

    xhr.onerror = () => {
      console.error("Task toggle request failed")
    }

    xhr.send()
  }
}
