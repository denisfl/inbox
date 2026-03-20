import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  // ── Date shortcuts ────────────────────────────────────────────
  setToday() {
    this._setDate(new Date());
  }

  setTomorrow() {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    this._setDate(d);
  }

  setDaysAhead({ currentTarget }) {
    const d = new Date();
    d.setDate(d.getDate() + parseInt(currentTarget.dataset.days));
    this._setDate(d);
  }

  _setDate(d) {
    const v = d.toISOString().split("T")[0];
    const dateInput = this.element.querySelector('[name="task[due_date]"]');
    if (dateInput) dateInput.value = v;

    this.element.querySelectorAll(".date-shortcut").forEach((btn) => {
      btn.classList.remove("active");
    });
  }
}
