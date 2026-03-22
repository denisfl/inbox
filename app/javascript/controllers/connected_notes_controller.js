import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["popup", "popupTitle", "popupBody", "popupLink"];

  connect() {
    this._escHandler = (e) => {
      if (e.key === "Escape") this.closePopup();
    };
    document.addEventListener("keydown", this._escHandler);
  }

  disconnect() {
    document.removeEventListener("keydown", this._escHandler);
    if (this._outsideHandler) {
      document.removeEventListener("click", this._outsideHandler);
      this._outsideHandler = null;
    }
  }

  async openPopup(event) {
    if (event.target.closest(".connected-note-title")) return;

    const card = event.currentTarget;
    const docId = event.params.docId;
    const res = await fetch(`/documents/${docId}/preview`, {
      headers: { Accept: "application/json" },
    });
    if (!res.ok) return;

    const data = await res.json();
    this.popupTitleTarget.textContent = data.title;
    this.popupTitleTarget.href = data.url;
    this.popupBodyTarget.innerHTML = data.html;
    this.popupLinkTarget.href = data.url;
    this.popupTarget.hidden = false;

    this._positionPopup(card);
    this._bindOutsideClick();
  }

  titleClick(event) {
    event.stopPropagation();
  }

  closePopup() {
    if (!this.hasPopupTarget) return;
    this.popupTarget.hidden = true;
    if (this._outsideHandler) {
      document.removeEventListener("click", this._outsideHandler);
      this._outsideHandler = null;
    }
  }

  _positionPopup(anchor) {
    const rect = anchor.getBoundingClientRect();
    const popup = this.popupTarget;
    popup.style.position = "fixed";
    popup.style.maxHeight = "";

    // Position above the card by default
    popup.style.top = "0";
    popup.style.left = `${rect.left}px`;

    requestAnimationFrame(() => {
      const pw = popup.offsetWidth;
      const ph = popup.offsetHeight;
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      const margin = 16;

      let left = rect.left;
      // Above the anchor card
      let top = rect.top - ph - 8;

      // Horizontal: keep within viewport
      if (left + pw > vw - margin) {
        left = vw - pw - margin;
      }
      if (left < margin) left = margin;

      // If not enough space above, show below
      if (top < margin) {
        top = rect.bottom + 8;
      }
      // If still overflows bottom, pin to top and limit height
      if (top + ph > vh - margin) {
        top = margin;
        popup.style.maxHeight = `${vh - 2 * margin}px`;
      }

      popup.style.top = `${top}px`;
      popup.style.left = `${left}px`;
    });
  }

  _bindOutsideClick() {
    if (this._outsideHandler) {
      document.removeEventListener("click", this._outsideHandler);
    }
    this._outsideHandler = (e) => {
      if (!this.popupTarget.contains(e.target)) this.closePopup();
    };
    setTimeout(
      () => document.addEventListener("click", this._outsideHandler),
      100,
    );
  }
}
