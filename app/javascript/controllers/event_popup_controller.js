import { Controller } from "@hotwired/stimulus";

// Displays a detail popup near a calendar event on click.
// Usage:
//   <div data-controller="event-popup" data-event-popup-active-class="is-open">
//     <div data-action="click->event-popup#toggle" data-event-popup-target="trigger">
//       ... event summary ...
//     </div>
//     <div data-event-popup-target="popup" class="event-popup" hidden>
//       ... detail content ...
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["popup", "trigger"];

  connect() {
    this._onOutsideClick = this._onOutsideClick.bind(this);
    this._onKeydown = this._onKeydown.bind(this);
  }

  disconnect() {
    this._removeListeners();
  }

  toggle(e) {
    // Don't intercept clicks on links / buttons / forms inside the trigger
    if (e.target.closest("a, button, form, input")) return;

    e.stopPropagation();

    if (this.popupTarget.hidden) {
      this._open();
    } else {
      this._close();
    }
  }

  close() {
    this._close();
  }

  // ── private ──

  _open() {
    // Close any other open popups first
    document.querySelectorAll(".event-popup:not([hidden])").forEach((el) => {
      el.hidden = true;
    });

    this.popupTarget.hidden = false;
    this._positionPopup();

    // Defer listener attachment so current click doesn't immediately close
    requestAnimationFrame(() => {
      document.addEventListener("click", this._onOutsideClick, true);
      document.addEventListener("keydown", this._onKeydown);
    });
  }

  _close() {
    this.popupTarget.hidden = true;
    this._removeListeners();
  }

  _removeListeners() {
    document.removeEventListener("click", this._onOutsideClick, true);
    document.removeEventListener("keydown", this._onKeydown);
  }

  _onOutsideClick(e) {
    if (!this.element.contains(e.target)) {
      this._close();
    }
  }

  _onKeydown(e) {
    if (e.key === "Escape") {
      this._close();
    }
  }

  _positionPopup() {
    const popup = this.popupTarget;
    const rect = this.element.getBoundingClientRect();
    const vw = window.innerWidth;
    const vh = window.innerHeight;

    // Reset positioning
    popup.style.left = "";
    popup.style.right = "";
    popup.style.top = "";
    popup.style.bottom = "";
    popup.style.marginLeft = "";
    popup.style.marginRight = "";

    // On mobile: fixed bottom sheet
    if (vw <= 700) {
      popup.classList.add("event-popup--mobile");
      return;
    }

    popup.classList.remove("event-popup--mobile");

    // Use fixed positioning to avoid overflow:hidden clipping
    popup.style.position = "fixed";

    const popupWidth = 300;
    const spaceRight = vw - rect.right;

    // Horizontal: prefer right of element
    if (spaceRight >= popupWidth + 16) {
      popup.style.left = `${rect.right + 8}px`;
    } else {
      popup.style.left = `${rect.left - popupWidth - 8}px`;
    }

    // Vertical: align top with element
    let top = rect.top;

    // Defer to measure actual popup height and adjust if needed
    popup.style.top = `${top}px`;
    requestAnimationFrame(() => {
      const popupRect = popup.getBoundingClientRect();
      if (popupRect.bottom > vh - 16) {
        top = vh - 16 - popupRect.height;
        if (top < 16) top = 16;
        popup.style.top = `${top}px`;
      }
    });
  }
}
