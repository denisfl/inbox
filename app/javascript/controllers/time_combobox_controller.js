import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "hidden", "dropdown"];

  connect() {
    this._activeIndex = -1;
    this._previousValue = this.hiddenTarget.value || "";
    this._previousLabel = this.inputTarget.value || "";

    // If hidden has a value on connect, show formatted label
    if (this.hiddenTarget.value) {
      const slot = this.slots.find((s) => s.value === this.hiddenTarget.value);
      if (slot) this.inputTarget.value = slot.label;
    }
  }

  get slots() {
    if (this._slots) return this._slots;
    this._slots = [];
    for (let h = 0; h < 24; h++) {
      for (let m = 0; m < 60; m += 30) {
        const value = `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
        const label = this._formatLabel(h, m);
        this._slots.push({ value, label });
      }
    }
    return this._slots;
  }

  _formatLabel(h, m) {
    const period = h < 12 ? "AM" : "PM";
    const h12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
    return `${h12}:${String(m).padStart(2, "0")} ${period}`;
  }

  onFocus() {
    this._previousValue = this.hiddenTarget.value || "";
    this._previousLabel = this.inputTarget.value || "";
    this.inputTarget.select();
    this.showDropdown("");
  }

  onInput() {
    const query = this.inputTarget.value.trim();
    this.showDropdown(query);
  }

  onBlur() {
    setTimeout(() => {
      this.hideDropdown();
      this.commitTyped();
    }, 150);
  }

  onKeydown(e) {
    const items = this.dropdownTarget.querySelectorAll(
      ".time-combobox__option",
    );
    if (!items.length && !["Escape", "Tab"].includes(e.key)) return;

    switch (e.key) {
      case "ArrowDown":
        e.preventDefault();
        this._activeIndex = Math.min(this._activeIndex + 1, items.length - 1);
        this._highlightItem(items);
        break;
      case "ArrowUp":
        e.preventDefault();
        this._activeIndex = Math.max(this._activeIndex - 1, 0);
        this._highlightItem(items);
        break;
      case "Enter":
        e.preventDefault();
        if (this._activeIndex >= 0 && items[this._activeIndex]) {
          const item = items[this._activeIndex];
          this.selectItem(item.dataset.value, item.textContent);
        } else {
          this.commitTyped();
        }
        break;
      case "Escape":
        this.hideDropdown();
        this.inputTarget.blur();
        break;
      case "Tab":
        this.commitTyped();
        break;
    }
  }

  showDropdown(query) {
    const filtered = query
      ? this.slots.filter(
          (s) =>
            s.label.toLowerCase().includes(query.toLowerCase()) ||
            s.value.includes(query),
        )
      : this.slots;

    this._activeIndex = -1;
    const currentVal = this.hiddenTarget.value;

    let html = "";
    filtered.forEach((slot, i) => {
      const active = slot.value === currentVal;
      if (active) this._activeIndex = i;
      html += `<div class="time-combobox__option${active ? " time-combobox__option--active" : ""}"
                    data-value="${slot.value}"
                    data-action="mousedown->time-combobox#onOptionClick">${slot.label}</div>`;
    });

    this.dropdownTarget.innerHTML = html;
    this.dropdownTarget.classList.add("open");

    // Scroll to active item
    const activeEl = this.dropdownTarget.querySelector(
      ".time-combobox__option--active",
    );
    if (activeEl) {
      activeEl.scrollIntoView({ block: "nearest" });
    }
  }

  hideDropdown() {
    this.dropdownTarget.classList.remove("open");
  }

  onOptionClick(e) {
    const el = e.currentTarget;
    this.selectItem(el.dataset.value, el.textContent);
  }

  selectItem(value, label) {
    this.inputTarget.value = label.trim();
    this.hiddenTarget.value = value;
    this._previousValue = value;
    this._previousLabel = label.trim();
    this.hideDropdown();
    this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }));
  }

  commitTyped() {
    const raw = this.inputTarget.value.trim();
    if (!raw) {
      this.hiddenTarget.value = "";
      this._previousValue = "";
      this._previousLabel = "";
      return;
    }

    const parsed = this.parseTime(raw);
    if (parsed) {
      this.selectItem(parsed.value, parsed.label);
    } else {
      // Restore previous
      this.inputTarget.value = this._previousLabel;
      this.hiddenTarget.value = this._previousValue;
    }
  }

  parseTime(raw) {
    raw = raw.trim().toLowerCase();
    if (!raw) return null;

    let h, m;

    // Match "9am", "9pm", "9:30am", "9:30 pm", "930am"
    const ampm = raw.match(/^(\d{1,2}):?(\d{2})?\s*(am|pm)$/i);
    if (ampm) {
      h = parseInt(ampm[1]);
      m = ampm[2] ? parseInt(ampm[2]) : 0;
      if (ampm[3].toLowerCase() === "pm" && h !== 12) h += 12;
      if (ampm[3].toLowerCase() === "am" && h === 12) h = 0;
    } else {
      // "14:00", "9:30", "1400", "930", "9"
      const mil = raw.match(/^(\d{1,2}):(\d{2})$/);
      if (mil) {
        h = parseInt(mil[1]);
        m = parseInt(mil[2]);
      } else if (/^\d{3,4}$/.test(raw)) {
        // "930" → 9:30, "1400" → 14:00
        const padded = raw.padStart(4, "0");
        h = parseInt(padded.slice(0, 2));
        m = parseInt(padded.slice(2));
      } else if (/^\d{1,2}$/.test(raw)) {
        h = parseInt(raw);
        m = 0;
      } else {
        return null;
      }
    }

    if (h < 0 || h > 23 || m < 0 || m > 59) return null;

    const value = `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
    const label = this._formatLabel(h, m);
    return { value, label };
  }

  _highlightItem(items) {
    items.forEach((el, i) => {
      el.classList.toggle(
        "time-combobox__option--active",
        i === this._activeIndex,
      );
    });
    if (items[this._activeIndex]) {
      items[this._activeIndex].scrollIntoView({ block: "nearest" });
    }
  }
}
