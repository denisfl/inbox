## Why

Several UI patterns are inconsistent or limiting: task descriptions are hidden behind an icon instead of being previewed, event datetime inputs use combined `datetime-local` fields that are awkward on mobile, and back buttons always go to a fixed route instead of the actual previous page.

## What Changes

- **Tasks list**: Replace the "task-has-desc" icon with a 1–2 line description preview beneath the title; make the task title a clickable link that navigates to a new task show page
- **Task show page**: Add a read-only show view for tasks (new route + controller action + view)
- **Event form**: Split `datetime_local_field` for `starts_at` / `ends_at` into separate date and time inputs
- **Back button**: Change `back_link` helper to use browser history (`javascript:history.back()`) with a fallback path, so the back button returns to the actual previous page

## Capabilities

### New Capabilities

- `task-show-page`: Read-only show view for individual tasks with full description and metadata

### Modified Capabilities

_(no existing spec-level requirements are changing)_

## Impact

- **Routes**: Add `show` action to tasks resource
- **Controllers**: Add `TasksController#show`; modify `CalendarEventsController` strong params to accept separate date/time fields
- **Views**: Modify `tasks/_task.html.erb`, add `tasks/show.html.erb`, modify `calendar_events/_form.html.erb`, modify all views using `back_link`
- **Helpers**: Modify `back_link` in `application_helper.rb`
- **Models**: Add virtual attributes or controller-level merging for separate date/time event inputs
- **JS**: May need a Stimulus controller if date+time merging is done client-side
