## Context

The calendar weekly view (`calendar?view=week`) currently renders events as a flat vertical list inside each day column. There is no time axis — a 9:00 event and a 17:00 event sit next to each other with no spatial indication of when they occur. Users must read time labels manually.

On the Dashboard Events block and the Agenda view, past timed events are visually identical to future ones. The only way to know an event has passed is to mentally compare its time label to the current time.

The app uses inline `<style>` blocks in view templates, Stimulus controllers for interactivity, and CSS custom properties for theming. No external CSS framework.

## Goals / Non-Goals

**Goals:**
- Weekly view: render events on a vertical time grid so their position reflects actual time of day
- Weekly view: show a left-side time axis with hour labels
- Weekly view: all-day events displayed in a dedicated row above the time grid
- Dashboard + Agenda: past timed events get reduced opacity
- No new JS dependencies; minimal Stimulus controller additions

**Non-Goals:**
- Drag-and-drop event moving/resizing
- Current-time indicator line (nice-to-have, may add later)
- Multi-day event spanning across columns
- Changing the month view or any other view not mentioned

## Decisions

### 1. Time grid via CSS Grid rows (not absolute positioning)

Use CSS Grid with rows representing 30-minute slots. Each hour = 2 rows. The grid defines the spatial layout natively.

**Why over absolute positioning:** CSS Grid keeps the layout in the flow, avoids manual pixel calculations, works better with dynamic content, and is easier to maintain. Absolute positioning requires JS for overlap detection and resize handling.

**Structure:**
```
.week-timeline
  .week-allday-row          ← all-day events strip
  .week-time-grid
    .week-time-labels        ← left column with hour markers
    .week-day-col × 7        ← each day is a grid column
      .week-timed-event      ← placed via grid-row-start / grid-row-end
```

**Hour range:** Display 07:00–23:00 (32 half-hour slots = 32 rows). Events outside this range get clamped to the visible area. This covers the practical day without wasting space on 0:00–6:00.

**Event placement:**
- `grid-row-start` = `(hour - 7) * 2 + (minute >= 30 ? 2 : 1)` (1-based)
- `grid-row-end` = start + `ceil(duration_minutes / 30)`, minimum span of 1
- Events without `ends_at`: span 1 row (30 min default visual height)

### 2. All-day events in a separate row above the grid

All-day events and documents/tasks without a specific time go into a horizontal strip above the time grid. This keeps the time grid clean and avoids placing items at arbitrary positions.

**Why:** Google Calendar, Outlook, and Apple Calendar all use this pattern. Users expect all-day events separate from timed events.

### 3. Past event detection: `CalendarEvent#past?` instance method

```ruby
def past?
  return false if all_day?
  (ends_at || starts_at) < Time.current
end
```

**Why a model method:** Reusable across all views. Simple predicate, no caching or DB queries needed. Uses `ends_at` when available (event is past only after it ends), falls back to `starts_at`. All-day events excluded — they represent the whole day and don't have a meaningful "past" moment during the day.

### 4. Past event styling: CSS class + opacity

Add `--past` modifier class to event containers in Agenda and Dashboard views:
- `.agenda-entry--past { opacity: 0.55; }` 
- `.dash-ev--past { opacity: 0.55; }`

**Why 0.55:** Clearly dimmed but still readable. 0.3 is too faint; 0.7 is too subtle.

**Why CSS class over inline style:** Themeable, hover-overridable (`&:hover { opacity: 1; }`), no logic in templates beyond the class toggle.

### 5. Helper methods for week grid placement

Add to `CalendarEvent` or a view helper:

```ruby
def grid_row_start(day_start_hour: 7)
  return nil if all_day?
  offset_minutes = [(starts_at.hour - day_start_hour) * 60 + starts_at.min, 0].max
  (offset_minutes / 30) + 1  # 1-based for CSS Grid
end

def grid_row_span
  return 1 if all_day? || ends_at.blank?
  slots = (duration_minutes / 30.0).ceil
  [slots, 1].max
end
```

These stay in the model since they derive purely from model attributes. If they become complex, extract to a presenter later.

### 6. Mobile: collapse to single-column scroll

On screens < 700px, the week grid collapses to a vertical list (similar to current agenda), since a 7-column time grid is unusable on mobile. The existing `@media (max-width: 700px)` breakpoint already handles this — extend it.

### 7. Documents and tasks in week timeline

- **Tasks with `due_time`:** Placed on the time grid at their due time, styled differently (no color bar, primary color accent)
- **Tasks without `due_time` / Documents:** Placed in the all-day strip at the top of the day column

## Risks / Trade-offs

- **[Overlapping events]** → Two events at the same time will overlap visually. Mitigation: for v1, allow overlap with slight padding. Column-splitting (like Google Calendar) is complex and deferred to a future iteration.
- **[Performance for many events]** → A week with 50+ timed events could create many absolutely-placed grid items. Mitigation: the current data model rarely has more than ~10 events per day. No performance concern for typical usage.
- **[Hour range hardcoded to 7:00–23:00]** → Early-morning events (before 7:00) get visually clamped. Mitigation: this covers >95% of use cases. Can be made configurable later if needed.
- **[All-day strip height]** → Many all-day events could push the time grid down. Mitigation: limit visible all-day events to 3 with an expandable "+N more" link.

## Open Questions

_(none — all decisions documented above)_
