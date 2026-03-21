import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["menu"];

  toggle(event) {
    event.stopPropagation();
    this.element.classList.toggle("open");
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.element.classList.remove("open");
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.element.classList.remove("open");
    }
  }

  connect() {
    this._close = this.close.bind(this);
    this._escape = this.closeOnEscape.bind(this);
    document.addEventListener("click", this._close);
    document.addEventListener("keydown", this._escape);
  }

  disconnect() {
    document.removeEventListener("click", this._close);
    document.removeEventListener("keydown", this._escape);
  }
}
