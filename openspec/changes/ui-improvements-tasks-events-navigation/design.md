## Context

The inbox app has several UI rough edges:

- **Tasks**: Description is indicated only by a small document icon ("task-has-desc"). Users must click edit to see the description. The task title is plain text — clicking anywhere on the task row opens the edit form, which is destructive.
- **Events**: The `datetime_local_field` combines date and time into a single native input, which is awkward to use (especially on desktop where the picker varies by browser).
- **Back button**: The `back_link` helper hardcodes a specific route (e.g., `tasks_path`, `calendar_path`). If a user navigated from the dashboard to a task edit page, the back button takes them to the tasks list instead of back to the dashboard.

## Goals / Non-Goals

**Goals:**

- Show 1–2 lines of task description preview directly in the task list
- Make task title a link to a new read-only show page
- Split event datetime inputs into separate date + time fields
- Make the back button use browser history navigation

**Non-Goals:**

- Full task detail redesign (just description preview + show page)
- Event form validation changes beyond field layout
- Changing URL structure or API endpoints

## Decisions

### 1. Task description preview

Replace the `task-has-desc` icon with a truncated description text (2 lines max via CSS `line-clamp`). Keep it lightweight — no markdown rendering in the list view.

### 2. Task show page

Add `TasksController#show` + `tasks/show.html.erb`. Route: `GET /tasks/:id`. The show page displays full title, description (markdown-rendered), due date/time, tags, and status. Title in the list becomes `link_to task.title, task_path(task)`.

### 3. Event date/time split

Replace each `datetime_local_field` with `date_field` + `time_field`. In the controller, merge them back into a single `starts_at` / `ends_at` datetime before saving. No client-side JS merging needed — controller handles it server-side with `Date.parse(date_param) + Tod::TimeOfDay.parse(time_param)` or simple string concatenation + `Time.zone.parse`.

### 4. Back button via browser history

Change `back_link(path, label)` to render `onclick="history.back(); return false;"` with the `href` set to the fallback path. If JS is disabled, the link still works via the fallback. No schema or routing changes required.

## Risks / Trade-offs

- **[Task show page routing]** Adding `:show` to `resources :tasks` may interfere if any other code assumes tasks have no show route. → Mitigation: straightforward RESTful route, low risk.
- **[Date/time split UX]** Separate date + time inputs may be less compact than a single `datetime-local`. → Mitigation: Field group layout keeps them visually paired.
- **[Back button history.back()]** If the user navigated directly to a page (no history), `history.back()` does nothing. → Mitigation: fallback `href` attribute ensures the link still functions via normal navigation.
