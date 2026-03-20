import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["durationRow"];

  connect() {
    const startTime = this.element.querySelector(
      '[name="calendar_event[starts_at_time]"]',
    );
    if (startTime)
      startTime.addEventListener("change", (e) => this.onStartTimeChange(e));

    const endTime = this.element.querySelector(
      '[name="calendar_event[ends_at_time]"]',
    );
    if (endTime)
      endTime.addEventListener("change", (e) => this.onEndTimeModified(e));

    const startDate = this.element.querySelector(
      '[name="calendar_event[starts_at_date]"]',
    );
    if (startDate)
      startDate.addEventListener("change", (e) => this.startDateChanged(e));

    // Initial all-day state
    const allDay = this.element.querySelector("#event_all_day");
    if (allDay) this._setTimeFieldsVisibility(!allDay.checked);
  }

  onStartTimeChange({ target }) {
    const val = target.value;
    if (!val) return;
    const [h, m] = val.split(":").map(Number);
    const endH = (h + 1) % 24;
    const endVal = `${String(endH).padStart(2, "0")}:${String(m).padStart(2, "0")}`;

    const endHidden = this.element.querySelector(
      '[name="calendar_event[ends_at_time]"]',
    );
    if (endHidden && !endHidden.dataset.userModified) {
      endHidden.value = endVal;
      endHidden.dispatchEvent(new Event("change", { bubbles: true }));
    }
  }

  onEndTimeModified({ target }) {
    target.dataset.userModified = "true";
  }

  startDateChanged({ target }) {
    const endDate = this.element.querySelector(
      '[name="calendar_event[ends_at_date]"]',
    );
    if (endDate && !endDate.dataset.userModified) endDate.value = target.value;
  }

  toggleAllDay({ target }) {
    this._setTimeFieldsVisibility(!target.checked);
  }

  _setTimeFieldsVisibility(show) {
    this.element
      .querySelectorAll("[data-time-field]")
      .forEach((el) => (el.style.display = show ? "" : "none"));
    if (this.hasDurationRowTarget) {
      this.durationRowTarget.style.display = show ? "" : "none";
    }
  }

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
    const startDate = this.element.querySelector(
      '[name="calendar_event[starts_at_date]"]',
    );
    if (startDate) startDate.value = v;
    const endDate = this.element.querySelector(
      '[name="calendar_event[ends_at_date]"]',
    );
    if (endDate && !endDate.dataset.userModified) endDate.value = v;

    // Highlight active shortcut
    this.element.querySelectorAll(".date-shortcut").forEach((btn) => {
      btn.classList.remove("active");
    });
  }

  // ── Duration presets ──────────────────────────────────────────
  setDuration({ currentTarget }) {
    const minutes = parseInt(currentTarget.dataset.minutes);
    const startVal = this.element.querySelector(
      '[name="calendar_event[starts_at_time]"]',
    ).value;
    if (!startVal) return;

    const [h, m] = startVal.split(":").map(Number);
    const total = (h * 60 + m + minutes) % 1440;
    const endH = Math.floor(total / 60);
    const endM = total % 60;
    const endVal = `${String(endH).padStart(2, "0")}:${String(endM).padStart(2, "0")}`;

    const endHidden = this.element.querySelector(
      '[name="calendar_event[ends_at_time]"]',
    );
    if (endHidden) {
      endHidden.value = endVal;
      endHidden.dispatchEvent(new Event("change", { bubbles: true }));
    }

    this.element
      .querySelectorAll(".duration-btn")
      .forEach((b) => b.classList.toggle("active", b === currentTarget));
  }
}
