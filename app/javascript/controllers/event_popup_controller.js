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
    this._onCloseClick = () => this._close();
    // Cache popup reference before any teleport moves it out of scope
    this._popup = this.popupTarget;
    // Bind close button directly (Stimulus actions won't route after teleport)
    this._closeBtn = this._popup.querySelector(".event-popup-close");
    if (this._closeBtn) {
      this._closeBtn.addEventListener("click", this._onCloseClick);
    }
  }

  disconnect() {
    if (this._closeBtn) {
      this._closeBtn.removeEventListener("click", this._onCloseClick);
    }
    this._close();
  }

  toggle(e) {
    // Don't intercept clicks on links / buttons / forms inside the trigger
    if (e.target.closest("a, button, form, input")) return;

    e.stopPropagation();

    if (this._popup.hidden) {
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

    // Teleport popup to body so it escapes any stacking contexts
    this._originalParent = this._popup.parentElement;
    this._originalNextSibling = this._popup.nextSibling;
    document.body.appendChild(this._popup);

    this._popup.hidden = false;
    this._positionPopup();

    // Defer listener attachment so current click doesn't immediately close
    requestAnimationFrame(() => {
      document.addEventListener("click", this._onOutsideClick, true);
      document.addEventListener("keydown", this._onKeydown);
    });
  }

  _close() {
    if (!this._popup) return;
    this._popup.hidden = true;
    // Return popup to its original DOM position
    if (this._originalParent) {
      this._originalParent.insertBefore(this._popup, this._originalNextSibling);
      this._originalParent = null;
      this._originalNextSibling = null;
    }
    this._removeListeners();
  }

  _removeListeners() {
    document.removeEventListener("click", this._onOutsideClick, true);
    document.removeEventListener("keydown", this._onKeydown);
  }

  _onOutsideClick(e) {
    if (!this.element.contains(e.target) && !this._popup.contains(e.target)) {
      this._close();
    }
  }

  _onKeydown(e) {
    if (e.key === "Escape") {
      this._close();
    }
  }

  _positionPopup() {
    const popup = this._popup;
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
