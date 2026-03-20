## MODIFIED Requirements

### Requirement: Past timed events show reduced opacity on Agenda view

On the Agenda view (`calendar?view=agenda`), timed events whose end time (or start time if no end time) is in the past SHALL be rendered with reduced opacity (0.55). All-day events SHALL NOT be affected. Event descriptions in the agenda view SHALL be rendered as Action Text rich text content instead of Markdown.

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

#### Scenario: Event description renders as rich text

- **WHEN** an event with formatted description is displayed on the Agenda view
- **THEN** the description is rendered as Action Text HTML (not Markdown)
