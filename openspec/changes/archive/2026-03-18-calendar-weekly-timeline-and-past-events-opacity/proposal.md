## Why

The weekly calendar view stacks events as a flat list per day without reflecting their actual time placement — making it hard to gauge daily schedules at a glance. Additionally, past timed events on the Dashboard (Events block) and Agenda view look the same as upcoming ones, so there's no visual signal that they've already passed.

## What Changes

- **Weekly view timeline layout**: Replace the vertical stack in each day column with a time-slot grid where events are positioned at their actual hour. Add a horizontal time axis (hours labels on the left) so users can scan the day's schedule spatially.
- **Past event opacity (Dashboard + Agenda)**: Timed events whose `ends_at` (or `starts_at` for events without `ends_at`) is in the past get reduced opacity, making it immediately clear they've concluded. All-day events are excluded from this treatment.

## Capabilities

### New Capabilities
- `weekly-timeline`: Time-grid layout for the `calendar?view=week` page — hour rows, time axis, and event blocks positioned by start/end time.

### Modified Capabilities
- `transcription-correction`: (no changes)

*No existing specs are modified. This is additive.*

### Modified Capabilities

_(none — no existing spec requirements change)_

## Impact

- **Views**: `app/views/calendars/index.html.erb` (week section, agenda section), `app/views/dashboard/index.html.erb` (events block)
- **CSS**: Inline `<style>` blocks within those views (week grid styles, agenda entry styles, dashboard event styles)
- **Models**: No schema changes. May add a helper/method for "is this event in the past?" if one doesn't exist (`CalendarEvent#past?`).
- **JS/Stimulus**: Possibly a lightweight controller for the current-time indicator line in the weekly view, but otherwise no new JS dependencies.
- **No breaking changes, no API changes, no dependency additions.**
