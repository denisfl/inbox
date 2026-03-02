import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "submit", "dropzone"]

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.closest(".upload-card").classList.add("drag-over")
  }

  dragenter(event) {
    event.preventDefault()
    this.dropzoneTarget.closest(".upload-card").classList.add("drag-over")
  }

  dragleave(event) {
    event.preventDefault()
    this.dropzoneTarget.closest(".upload-card").classList.remove("drag-over")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.closest(".upload-card").classList.remove("drag-over")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.inputTarget.files = files
      this._updateLabel(files)
    }
  }

  change() {
    const files = this.inputTarget.files
    if (files.length > 0) {
      this._updateLabel(files)
    }
  }

  _updateLabel(files) {
    const count = files.length
    const label = count === 1
      ? files[0].name
      : `${count} files selected`
    this.labelTarget.textContent = label
    this.submitTarget.style.display = "flex"
  }
}
