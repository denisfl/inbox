## Why

Inbox currently saves todo-type messages from Telegram as documents (`document_type: 'todo'`). These are just notes with a `#todo` tag — they don't have due dates, priorities, completion tracking, or calendar integration. There is no dedicated task management: no way to see "what's due today", no overdue warnings, no recurring tasks.

Users naturally think in terms of actionable tasks with deadlines: "купить молоко завтра", "оплатить счёт 1 марта", "проверять почту каждый день". The system should support this natively.

## What Changes

- New `Task` model — standalone entity (not extracted from markdown, not a Document)
- Tasks have: title, markdown description, due date (optional), due time (optional), priority (pinned/high/mid/low), completion tracking, recurrence rules
- Dedicated `/tasks` page with smart views: Today, Upcoming, Inbox (no date), Overdue, Completed
- Calendar integration: tasks with `due_date` appear on the calendar timeline alongside Google Calendar events
- Telegram integration: `IntentRouter` creates `Task` instead of `Document` when intent is `todo`
- Recurring tasks: on completion, automatically generate the next occurrence

## Capabilities

### New Capabilities

- `task-management`: CRUD for tasks with title, description (markdown), due_date, due_time, priority, completion status. No TaskList grouping — flat list with smart views.
- `task-views`: Page at `/tasks` with filters: Today (due today + pinned), Upcoming (future dates grouped by day), Inbox (no due date), All active, Completed. Sorted by priority then position.
- `task-calendar-integration`: Tasks with `due_date` appear in the calendar timeline (`CalendarsController`) as a third entry type alongside events and documents.
- `task-recurrence`: Recurring tasks (`daily`, `weekly`, `monthly`, `yearly`). On completion, system creates the next occurrence with the computed next due date. Template fields (title, description, priority, recurrence rule) carry over.
- `task-toggle`: Quick toggle endpoint (`PATCH /tasks/:id/toggle`) for checking/unchecking tasks from any view (task list, calendar, sidebar).

### Modified Capabilities

- `intent-routing` in `IntentRouter#dispatch`: `todo` intent now creates a `Task` (with `due_date` from `IntentClassifierService.due_at`) instead of a `Document`
- `calendar-timeline` in `CalendarsController#index`: `build_timeline` merges tasks alongside events and documents
- `calendar-widget` in `CalendarsController#widget`: shows today's tasks count

### New Components

- `Task` model — `app/models/task.rb`
- `TasksController` — `app/controllers/tasks_controller.rb` (CRUD + toggle + index with filters)
- Views: `app/views/tasks/` — index, new, edit, _task partial
- Migration: `create_tasks`

### Removed/Replaced

- `IntentRouter#create_todo` — no longer creates Document; creates Task instead
- `Document.todos` scope — deprecated (existing todo documents remain, but new ones go to Task)

## Data Model

### `tasks` table

| Column | Type | Default | Notes |
|---|---|---|---|
| `title` | string | — | Required |
| `description` | text | nil | Markdown content |
| `due_date` | date | nil | nil = no date (Inbox) |
| `due_time` | time | nil | nil = date-only task; set = specific time |
| `priority` | string | `"mid"` | `pinned` / `high` / `mid` / `low` |
| `completed` | boolean | false | — |
| `completed_at` | datetime | nil | Set on completion |
| `position` | integer | 0 | Ordering within view |
| `recurrence_rule` | string | nil | nil / `daily` / `weekly` / `monthly` / `yearly` |
| `document_id` | references | nil | Optional link to related note |
| `created_at` | datetime | — | — |
| `updated_at` | datetime | — | — |

**Indexes:** `[completed, due_date]`, `[completed, priority, position]`, `[due_date]`

### Priority levels

| Priority | Label | Behavior |
|---|---|---|
| `pinned` | 📌 Закреплённая | Always at top in any view |
| `high` | 🔴 Высокий | Above normal, visually highlighted |
| `mid` | ⚪ Обычный | Default |
| `low` | 🔵 Низкий | Bottom of list, muted style |

### Recurrence rules

| Rule | Next occurrence logic |
|---|---|
| `daily` | `due_date + 1.day` |
| `weekly` | `due_date + 1.week` |
| `monthly` | `due_date + 1.month` |
| `yearly` | `due_date + 1.year` |

On `complete!`: if `recurrence_rule` present → create new Task with same title/description/priority/recurrence_rule and computed next `due_date`.

## UI Screens

### `/tasks` — Main task page

**Navigation tabs:**
- 📥 Входящие — tasks without due_date
- 📌 Сегодня — due today + all pinned
- 📅 Предстоящие — future due_date, grouped by day
- 📋 Все — all active tasks
- ✅ Выполненные — completed tasks

**Task list:**
- Each task: checkbox + priority indicator + title + due date badge
- Click → expand description (rendered markdown)
- Quick add field at top

### Calendar integration

Tasks appear in the calendar timeline with:
- ☐ Checkbox (toggle from calendar)
- Priority color/icon
- Title
- Due time if set

### Telegram

- "Купить молоко завтра" → `Task(title: "Купить молоко", due_date: tomorrow)`
- "Оплатить счёт 1 марта" → `Task(title: "Оплатить счёт", due_date: 2026-03-01)`
- "Позвонить маме" → `Task(title: "Позвонить маме", due_date: nil)` (goes to Inbox)

## Impact

- **Database**: 1 new table (`tasks`), no changes to existing tables
- **Routes**: new `/tasks` resource + toggle/move member actions
- **IntentRouter**: `create_todo` creates Task instead of Document
- **CalendarsController**: `build_timeline` includes tasks
- **No breaking changes**: existing todo Documents remain untouched, system just stops creating new ones
- **No new infrastructure**: no new gems, no external services
