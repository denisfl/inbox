import { Controller } from "@hotwired/stimulus";

// Sidebar controller — handles mobile open/close
export default class extends Controller {
  static targets = ["panel", "overlay"];

  toggle() {
    const isOpen = this.panelTarget.classList.toggle("open");
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.toggle("open", isOpen);
    }
    document.body.style.overflow = isOpen ? "hidden" : "";
  }

  close() {
    this.panelTarget.classList.remove("open");
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("open");
    }
    document.body.style.overflow = "";
  }
}
