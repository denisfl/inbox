## 1. Task description preview

- [x] 1.1 In `app/views/tasks/_task.html.erb`, replace the `task-has-desc` icon indicator with a description text element (1–2 lines, CSS `line-clamp: 2`)
- [x] 1.2 Add CSS class `task-item-desc` with styles: `font-size: var(--text-xs)`, `color: var(--color-text-tertiary)`, `display: -webkit-box`, `-webkit-line-clamp: 2`, `overflow: hidden`

## 2. Task show page

- [x] 2.1 Add `:show` to tasks resource in `config/routes.rb`
- [x] 2.2 Add `TasksController#show` action with `@task = Task.find(params[:id])`
- [x] 2.3 Create `app/views/tasks/show.html.erb` with read-only display: title, description (markdown-rendered), due date/time, tags, completion status, back link
- [x] 2.4 In `app/views/tasks/_task.html.erb`, make the task title a `link_to task.title, task_path(task)`

## 3. Event form date/time split

- [x] 3.1 In `app/views/calendar_events/_form.html.erb`, replace `datetime_local_field :starts_at` with separate `date_field` + `time_field`
- [x] 3.2 In `app/views/calendar_events/_form.html.erb`, replace `datetime_local_field :ends_at` with separate `date_field` + `time_field`
- [x] 3.3 In `CalendarEventsController`, merge separate date+time params into `starts_at` / `ends_at` datetime before saving

## 4. Back button browser history

- [x] 4.1 Modify `back_link` helper in `app/helpers/application_helper.rb` to add `onclick="history.back(); return false;"` while keeping the `href` as fallback
- [x] 4.2 Verify all existing `back_link` usages still work (tasks/new, tasks/edit, events/new, events/edit, documents/edit)

## 5. Verification

- [x] 5.1 Run `bundle exec rubocop -A` and fix any offenses
- [x] 5.2 Run model and controller specs to confirm no regressions
- [ ] 5.3 Manual check: task list shows description preview, title links to show page
- [ ] 5.4 Manual check: event form date/time fields work correctly
- [ ] 5.5 Manual check: back button navigates to previous page in history
