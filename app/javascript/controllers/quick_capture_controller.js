import { Controller } from "@hotwired/stimulus";

// Quick Capture widget — toggles Note / Task / Event type
export default class extends Controller {
  static targets = ["typeField", "form"];

  setType(event) {
    const btn = event.currentTarget;
    const type = btn.dataset.type;

    // Update hidden field
    if (this.hasTypeFieldTarget) {
      this.typeFieldTarget.value = type;
    }

    // Toggle active class on buttons
    this.element.querySelectorAll(".qc-type").forEach((el) => {
      el.classList.toggle("active", el === btn);
    });
  }

  submit(event) {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit();
    }
  }
}
