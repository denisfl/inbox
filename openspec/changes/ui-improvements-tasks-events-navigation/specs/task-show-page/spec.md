## ADDED Requirements

### Requirement: Task description preview in list

The task list SHALL display up to 2 lines of the task's description text directly below the title, replacing the "task-has-desc" icon indicator.

#### Scenario: Task with description

- **WHEN** a task has a non-empty description
- **THEN** the task list item displays the description text truncated to 2 lines below the title

#### Scenario: Task without description

- **WHEN** a task has no description
- **THEN** no description preview is shown, and no "task-has-desc" icon is rendered

### Requirement: Task title links to show page

The task title in the list SHALL be a clickable link that navigates to the task show page.

#### Scenario: Clicking task title

- **WHEN** user clicks the task title text in the task list
- **THEN** the browser navigates to the task show page (`/tasks/:id`)

### Requirement: Task show page

The system SHALL provide a read-only show page for individual tasks at `GET /tasks/:id`.

#### Scenario: Viewing a task with full details

- **WHEN** user visits `/tasks/:id`
- **THEN** the page displays the task title, full description (markdown-rendered), due date, due time, tags, and completion status

#### Scenario: Task not found

- **WHEN** user visits `/tasks/:id` with a non-existent id
- **THEN** the system returns a 404 response

### Requirement: Event form separate date and time inputs

The event create/edit form SHALL display starts_at and ends_at as separate date and time input fields.

#### Scenario: Creating an event with date and time

- **WHEN** user fills in the start date field and start time field and submits
- **THEN** the system combines them into a single `starts_at` datetime and saves the event

#### Scenario: Editing an event with existing datetime

- **WHEN** user opens the edit form for an event with starts_at = "2025-01-15 14:30"
- **THEN** the date field shows "2025-01-15" and the time field shows "14:30"

### Requirement: Back button uses browser history

The back link across all pages SHALL navigate to the previous page in browser history, with a fallback to a hardcoded path when no history exists.

#### Scenario: Back from page with history

- **WHEN** user navigated from dashboard to task edit and clicks back
- **THEN** the browser returns to the dashboard (previous history entry)

#### Scenario: Back from direct URL access

- **WHEN** user opens a task edit page directly (no browser history) and clicks back
- **THEN** the browser navigates to the fallback path (e.g., tasks list)
