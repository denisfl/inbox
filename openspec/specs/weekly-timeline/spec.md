## ADDED Requirements

### Requirement: Weekly view displays a vertical time grid

The calendar weekly view (`calendar?view=week`) SHALL render a vertical time grid with hour rows spanning 07:00–23:00. Each day SHALL occupy a column. A time axis with hour labels SHALL be displayed on the left side of the grid.

#### Scenario: Time axis is visible
- **WHEN** user navigates to `calendar?view=week`
- **THEN** a vertical axis on the left displays hour labels from 7:00 to 23:00 at 1-hour intervals

#### Scenario: Seven day columns are rendered
- **WHEN** user navigates to `calendar?view=week`
- **THEN** seven day columns are displayed for Monday through Sunday of the selected week

### Requirement: Timed events are positioned by their start time

Timed events (not all-day) SHALL be placed in the grid at the row corresponding to their `starts_at` hour and minute. Event height SHALL reflect duration proportionally (each 30-minute slot = 1 grid row).

#### Scenario: Event at 10:00 appears at the 10:00 row
- **WHEN** a timed event with `starts_at` at 10:00 exists on a weekday
- **THEN** the event block starts at the 10:00 row in that day's column

#### Scenario: Event duration determines block height
- **WHEN** a timed event spans 90 minutes (e.g., 10:00–11:30)
- **THEN** the event block spans 3 grid rows (3 x 30-min slots)

#### Scenario: Event without ends_at gets minimum height
- **WHEN** a timed event has no `ends_at`
- **THEN** the event block spans 1 grid row (30-min default)

#### Scenario: Event before 07:00 is clamped
- **WHEN** a timed event starts before 07:00
- **THEN** the event block is placed at the top of the grid (row 1)

### Requirement: All-day events are displayed above the time grid

All-day events SHALL be rendered in a dedicated strip above the time grid, separate from timed events. Documents and tasks without a specific time SHALL also appear in this strip.

#### Scenario: All-day event appears in the top strip
- **WHEN** an all-day event exists on a weekday
- **THEN** it is displayed in the all-day strip above the time grid for that day's column

#### Scenario: Task without due_time appears in the all-day strip
- **WHEN** a task with `due_date` but no `due_time` exists on a weekday
- **THEN** it appears in the all-day strip for that day

#### Scenario: All-day strip limits visible items
- **WHEN** more than 3 all-day items exist on a single day
- **THEN** only 3 are shown with a "+N more" indicator

### Requirement: Week view navigation preserves existing behavior

Week navigation (previous/next arrows, date range title) SHALL continue to work as before. The view title SHALL display the date range of the current week.

#### Scenario: Navigate to previous week
- **WHEN** user clicks the previous-week arrow
- **THEN** the view shifts to the prior 7-day period with the time grid

### Requirement: Week view is responsive on mobile

On viewports narrower than 700px, the weekly time grid SHALL collapse to a single-column vertical layout (similar to agenda view) since a 7-column grid is not usable on small screens.

#### Scenario: Mobile collapses to single column
- **WHEN** viewport width is below 700px
- **THEN** the week view displays as a vertical list instead of a 7-column time grid

### Requirement: Past timed events show reduced opacity on Agenda view

On the Agenda view (`calendar?view=agenda`), timed events whose end time (or start time if no end time) is in the past SHALL be rendered with reduced opacity (0.55). All-day events SHALL NOT be affected.

#### Scenario: Past timed event is dimmed on Agenda
- **WHEN** a timed event with `ends_at` before the current time is displayed on the Agenda view
- **THEN** it is rendered with `opacity: 0.55`

#### Scenario: Ongoing event is not dimmed
- **WHEN** a timed event with `starts_at` in the past but `ends_at` in the future is displayed
- **THEN** it is rendered at full opacity

#### Scenario: All-day event is never dimmed
- **WHEN** an all-day event on today's date is displayed on the Agenda view
- **THEN** it is rendered at full opacity regardless of current time

#### Scenario: Hover reveals past event at full opacity
- **WHEN** user hovers over a dimmed past event
- **THEN** the event temporarily displays at full opacity

### Requirement: Past timed events show reduced opacity on Dashboard

In the Dashboard Events block, timed events whose end time (or start time if no end time) is in the past SHALL be rendered with reduced opacity (0.55). All-day events SHALL NOT be affected.

#### Scenario: Past timed event is dimmed on Dashboard
- **WHEN** a timed event under "Today" group has `ends_at` before the current time
- **THEN** it is rendered with `opacity: 0.55`

#### Scenario: Future event is not dimmed on Dashboard
- **WHEN** a timed event under "Today" group has `starts_at` in the future
- **THEN** it is rendered at full opacity

#### Scenario: Hover reveals past Dashboard event
- **WHEN** user hovers over a dimmed past event on Dashboard
- **THEN** the event temporarily displays at full opacity

### Requirement: CalendarEvent exposes a past? predicate

`CalendarEvent` SHALL provide a `past?` instance method that returns `true` when the event is timed (not all-day) and its `ends_at` (or `starts_at` if `ends_at` is nil) is before `Time.current`.

#### Scenario: Ended event is past
- **WHEN** `ends_at` is 30 minutes ago and `all_day?` is false
- **THEN** `past?` returns `true`

#### Scenario: All-day event is never past
- **WHEN** `all_day?` is true
- **THEN** `past?` returns `false` regardless of `starts_at`

#### Scenario: Ongoing event is not past
- **WHEN** `starts_at` is 1 hour ago and `ends_at` is 30 minutes from now
- **THEN** `past?` returns `false`
