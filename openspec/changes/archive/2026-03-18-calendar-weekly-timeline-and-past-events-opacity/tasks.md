## 1. Model layer

- [x] 1.1 Add `CalendarEvent#past?` method — returns `true` when timed event's `ends_at` (or `starts_at`) is before `Time.current`; always `false` for all-day events
- [x] 1.2 Add `CalendarEvent#grid_row_start(day_start_hour: 7)` — computes 1-based CSS Grid row from `starts_at`
- [x] 1.3 Add `CalendarEvent#grid_row_span` — computes row span from `duration_minutes`, minimum 1
- [x] 1.4 Add model specs for `past?`, `grid_row_start`, `grid_row_span`

## 2. Weekly timeline view

- [x] 2.1 Replace the flat `.week-grid` / `.week-day-events` HTML with time-grid structure: left time-axis column + 7 day columns using CSS Grid rows (07:00–23:00, 30-min slots)
- [x] 2.2 Add all-day strip above the time grid for all-day events, documents, and tasks without `due_time`; limit to 3 visible items with "+N more" indicator
- [x] 2.3 Position timed events using `grid-row-start` / `grid-row-end` based on model helpers; height proportional to duration
- [x] 2.4 Position timed tasks (with `due_time`) on the time grid at their due time row
- [x] 2.5 Add CSS for `.week-timeline`, `.week-time-labels`, `.week-timed-event`, all-day strip, and hour-row alternating background
- [x] 2.6 Preserve existing event popup (`data-controller="event-popup"`) on timed and all-day event items
- [x] 2.7 Update mobile breakpoint (< 700px) to collapse the time grid into a single-column vertical list

## 3. Past event opacity — Agenda view

- [x] 3.1 Add `agenda-entry--past` CSS class with `opacity: 0.55` and `&:hover { opacity: 1 }` transition
- [x] 3.2 In agenda event rendering, apply `agenda-entry--past` class when `ev.past?` is true

## 4. Past event opacity — Dashboard Events block

- [x] 4.1 Add `dash-ev--past` CSS class with `opacity: 0.55` and `&:hover { opacity: 1 }` transition
- [x] 4.2 In dashboard event rendering, apply `dash-ev--past` class when `event.past?` is true

## 5. Verification & Polish

- [x] 5.1 Manual check: weekly view shows time axis, events positioned correctly, all-day strip works
- [x] 5.2 Manual check: agenda and dashboard past events are dimmed, hover restores opacity
- [x] 5.3 Manual check: mobile (< 700px) week view collapses gracefully
- [x] 5.4 Run existing test suite to confirm no regressions
- [x] 5.5 Fix hour grid lines: visible in all columns (including those with events), all solid
- [x] 5.6 Fix event backgrounds: opaque via color-mix() to prevent grid lines showing through
- [x] 5.7 Fix popup z-index: teleport popup to body, fix close button, three-layer z-index architecture
- [x] 5.8 Add current time indicator (now-line) on today's column in weekly view
