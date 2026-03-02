---
id: test-coverage
artifact: proposal
---

## Why

The project has **121 test cases** covering only the Document/Block/Tag core (4 models, 2 API controllers, 4 system specs). After multiple feature stories were implemented — Tasks, Calendar, Telegram intent routing, Google Calendar sync, event reminders, transcription — **zero tests were added** for any of them.

Current state:
- **4 models tested** out of 8 (CalendarEvent, CalendarEventTag, Task, TaskTag — untested)
- **2 API controllers tested** out of 9 (Tags, DocumentTags, CalendarEventTags, TaskTags, Telegram — untested)
- **0 web controllers tested** out of 6 (Dashboard, Calendars, CalendarEvents, Tasks, Tags, Documents)
- **0 services tested** out of 4 (IntentClassifierService, IntentRouter, TelegramMessageHandler, GoogleCalendarService)
- **0 jobs tested** out of 3 (GoogleCalendarSyncJob, SendEventReminderJob, TranscribeAudioJob)
- **0 helpers tested** out of 4

Some existing specs may also be **outdated** (e.g. `IntentRouter` now creates Task instead of Document for `todo` intent, but no spec verifies this).

## What Changes

Comprehensive test suite covering all existing production code:

1. **Model specs** — for CalendarEvent, CalendarEventTag, Task, TaskTag
2. **Service specs** — for IntentClassifierService, IntentRouter, TelegramMessageHandler, GoogleCalendarService (with external API stubbing)
3. **Job specs** — for GoogleCalendarSyncJob, SendEventReminderJob, TranscribeAudioJob (with external service stubbing)
4. **Request specs** — for Api::TagsController, Api::DocumentTagsController, Api::CalendarEventTagsController, Api::TaskTagsController, Api::TelegramController
5. **Controller/request specs** — for TasksController, CalendarsController, CalendarEventsController, TagsController, DashboardController, DocumentsController (web)
6. **New factories** — CalendarEvent, CalendarEventTag, Task, TaskTag
7. **Cleanup** — remove empty `test/` directory, activate SimpleCov

## Capabilities

### New Capabilities

- `model-specs-calendar`: CalendarEvent model spec — validations, scopes (upcoming, today, tomorrow, this_week, in_range, needs_reminder), callbacks, instance methods
- `model-specs-task`: Task model spec — validations, scopes (active, completed, today, upcoming, inbox, overdue, tagged_with, in_date_range, ordered), complete!/uncomplete!/toggle!, recurrence logic
- `model-specs-join-tables`: CalendarEventTag and TaskTag specs — associations, uniqueness validations
- `service-spec-intent-classifier`: IntentClassifierService spec — LLM classification, confidence threshold, title/date extraction, error resilience, bilingual support (Ollama stubbed via WebMock)
- `service-spec-intent-router`: IntentRouter spec — todo→Task creation, event→Document fallback, note→Document, Telegram reply, error fallback
- `service-spec-telegram-handler`: TelegramMessageHandler spec — text/photo/voice/audio/document handling, PDF detection, intent routing integration
- `service-spec-google-calendar`: GoogleCalendarService spec — full/delta sync, event upsert, cancelled event removal, multi-calendar, auth error handling (Google API stubbed)
- `job-spec-calendar-sync`: GoogleCalendarSyncJob spec — delegates to service, retry behavior, error logging
- `job-spec-event-reminder`: SendEventReminderJob spec — finds events needing reminder, sends Telegram, marks reminded_at, no duplicate reminders
- `job-spec-transcribe-audio`: TranscribeAudioJob spec — downloads audio, calls Whisper, LLM correction, intent classification, updates document (Whisper/Ollama stubbed)
- `request-specs-api`: Specs for Api::TagsController, Api::DocumentTagsController, Api::CalendarEventTagsController, Api::TaskTagsController, Api::TelegramController
- `request-specs-web`: Specs for TasksController, CalendarsController, CalendarEventsController, TagsController, DashboardController, DocumentsController#destroy
- `test-infra`: New factories, SimpleCov activation, WebMock/VCR setup, shared contexts for auth

## Impact

- **No production code changes** — test-only additions
- **New gems** (test group): `webmock` for HTTP stubbing
- **New files**: ~25 spec files, ~6 factory files, ~2 support files
- **Updated files**: Gemfile (add webmock), spec/rails_helper.rb (SimpleCov, WebMock config)
- **Deleted**: `test/` directory (empty Minitest skeleton)
