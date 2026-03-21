## Tasks

### Group 1: StatusChecker service

- [ ] 1.1 Create `app/services/status_checker.rb` with methods: `check_all`, `check_database`, `check_transcriber`, `check_google_calendar`
- [ ] 1.2 Each check returns `{ status: :ok | :unavailable, name: String, details: String }`
- [ ] 1.3 Transcriber check: HTTP GET `ENV["TRANSCRIBER_URL"]/health` with 3s timeout, rescue to `:unavailable`
- [ ] 1.4 Google Calendar check: verify `ENV["GOOGLE_CALENDAR_ID"]` present + query `CalendarEvent.maximum(:updated_at)` for last sync time
- [ ] 1.5 Database check: `ActiveRecord::Base.connection.execute("SELECT 1")`

### Group 2: Admin controller and route

- [ ] 2.1 Create `app/controllers/admin/status_controller.rb` with `http_basic_authenticate_with` using `ENV["ADMIN_USER"]` / `ENV["ADMIN_PASSWORD"]`
- [ ] 2.2 `show` action gathers: `StatusChecker.check_all`, SolidQueue job stats, document counts by status
- [ ] 2.3 Add route: `namespace :admin do get "status", to: "status#show" end`

### Group 3: Status page view

- [ ] 3.1 Create `app/views/admin/status/show.html.erb` with plain HTML + Tailwind
- [ ] 3.2 Section: Integration statuses (Database, Transcriber, Google Calendar) with ok/unavailable badges
- [ ] 3.3 Section: Job queue — pending count by job class, failed jobs count, last execution per job type
- [ ] 3.4 Section: System stats — document counts by status (inbox/processing/evergreen), total tasks, total calendar events
- [ ] 3.5 Section: Last backup time, last calendar sync time
- [ ] 3.6 Add refresh link/button (simple page reload)

### Group 4: ErrorNotifierJob

- [ ] 4.1 Create `app/jobs/error_notifier_job.rb` — accepts `error_class`, `error_message`, `job_name`, `timestamp`
- [ ] 4.2 Send Telegram message to `ENV["TELEGRAM_ADMIN_CHAT_ID"]` using `Telegram::Bot::Client`
- [ ] 4.3 `discard_on StandardError` — never retry notification delivery, log at ERROR level on failure
- [ ] 4.4 Rate limiting: skip if same `error_class` was notified within last 5 minutes (use Rails.cache)

### Group 5: ApplicationJob failure hooks

- [ ] 5.1 Add `after_discard` callback in `ApplicationJob` that enqueues `ErrorNotifierJob` with failure details
- [ ] 5.2 Ensure existing jobs with custom `retry_on`/`discard_on` still trigger the hook appropriately

### Group 6: Slow operation instrumentation

- [ ] 6.1 Create `config/initializers/slow_operation_subscriber.rb` subscribing to `external_service.inbox`
- [ ] 6.2 Log warning when duration exceeds `ENV["SLOW_OPERATION_THRESHOLD"]` (default 5.0 seconds)
- [ ] 6.3 Add `ActiveSupport::Notifications.instrument` calls in `TranscribeAudioJob` (transcriber HTTP call) and `GoogleCalendarService` (API calls) as initial instrumentation points

### Group 7: Configuration

- [ ] 7.1 Add to `.env.example`: `ADMIN_USER`, `ADMIN_PASSWORD`, `TELEGRAM_ADMIN_CHAT_ID`, `SLOW_OPERATION_THRESHOLD`
- [ ] 7.2 Document new ENV vars in README

### Group 8: Tests

- [ ] 8.1 Unit tests for `StatusChecker` — mock HTTP for transcriber, test all three probes
- [ ] 8.2 Request spec for `GET /admin/status` — test auth required (401), auth success (200), content includes sections
- [ ] 8.3 Unit test for `ErrorNotifierJob` — sends Telegram message, discards on error, rate limiting works
- [ ] 8.4 Test `ApplicationJob` after_discard hook triggers `ErrorNotifierJob`
- [ ] 8.5 Test slow operation subscriber logs warning above threshold
