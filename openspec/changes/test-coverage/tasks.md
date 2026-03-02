---
id: test-coverage
artifact: tasks
---

## Tasks

### Phase 0: Infrastructure Setup

- [ ] **T0.1** Add `gem "webmock", "~> 3.23"` to Gemfile test group, run `bundle install`
- [ ] **T0.2** Activate SimpleCov: add `require 'simplecov'; SimpleCov.start 'rails'` at top of `spec/rails_helper.rb`
- [ ] **T0.3** Add `require 'webmock/rspec'` and `WebMock.disable_net_connect!(allow_localhost: true)` to `spec/rails_helper.rb`
- [ ] **T0.4** Uncomment `Rails.root.glob('spec/support/**/*.rb')` line in `spec/rails_helper.rb`
- [ ] **T0.5** Create `spec/support/api_auth.rb` — shared context for API token auth
- [ ] **T0.6** Create `spec/support/telegram_stub.rb` — shared context for Telegram API stubs
- [ ] **T0.7** Create `spec/support/ollama_stub.rb` — shared context for Ollama API stubs
- [ ] **T0.8** Remove `test/` directory (empty Minitest skeleton)
- [ ] **T0.9** Run existing specs — ensure all 121 pass with new infra (fix any WebMock conflicts)

### Phase 1: Model Specs

- [ ] **T1.1** Create `spec/factories/calendar_events.rb` — factory with traits: :google, :all_day, :today, :tomorrow, :past, :needs_reminder, :already_reminded, :cancelled
- [ ] **T1.2** Create `spec/factories/calendar_event_tags.rb`
- [ ] **T1.3** Create `spec/factories/tasks.rb` — factory with traits: :pinned, :high, :low, :completed, :due_today, :due_tomorrow, :overdue, :inbox, :recurring_daily, :recurring_weekly, :with_tags
- [ ] **T1.4** Create `spec/factories/task_tags.rb`
- [ ] **T1.5** Write `spec/models/calendar_event_spec.rb` (~25 tests):
  - Validations: google_event_id presence+uniqueness (when google), title presence, starts_at presence, status inclusion, source inclusion
  - Associations: has_many calendar_event_tags, has_many tags through
  - Callbacks: assign_local_uid for manual/ical, normalize_event_times for all_day, ends_at correction
  - Scopes: confirmed, google, manual, ical, upcoming, today, tomorrow, this_week, in_range, needs_reminder
  - Instance methods: duration_minutes, duration_label, display_color, time_label, local?, grouped_by_day
- [ ] **T1.6** Write `spec/models/calendar_event_tag_spec.rb` (~3 tests):
  - Associations: belongs_to calendar_event, belongs_to tag
  - Validation: uniqueness of calendar_event_id scoped to tag_id
- [ ] **T1.7** Write `spec/models/task_spec.rb` (~30 tests):
  - Validations: title presence, priority inclusion, recurrence_rule inclusion (allow nil)
  - Associations: belongs_to document (optional), has_many task_tags, has_many tags through
  - Callbacks: normalize_recurrence_rule
  - Scopes: active, completed, pinned, today (includes pinned), upcoming, inbox, overdue, with_due_date, tagged_with (AND logic), in_date_range, ordered (priority then position)
  - Instance methods: complete! (sets completed+completed_at, spawns recurrence), uncomplete!, toggle!, overdue?, due_today?, recurring?
  - Recurrence: daily/weekly/monthly/yearly spawn on complete!, no spawn without due_date, new task carries over fields
- [ ] **T1.8** Write `spec/models/task_tag_spec.rb` (~3 tests):
  - Associations: belongs_to task, belongs_to tag
  - Validation: uniqueness of task_id scoped to tag_id
- [ ] **T1.9** Run Phase 1 specs — verify all pass

### Phase 2: Service Specs

- [ ] **T2.1** Write `spec/services/intent_classifier_service_spec.rb` (~15 tests):
  - Classifies "купить молоко" → todo
  - Classifies "встреча в пятницу в 14:00" → event with due_at
  - Classifies "интересная идея" → note
  - Confidence < 0.65 → override to note
  - Title extraction from LLM response
  - Title fallback to text.truncate(80) when blank
  - Due date parsing (ISO8601)
  - Due date nil when unparseable
  - Ollama timeout → fallback to note
  - Ollama HTTP error → fallback to note
  - Malformed JSON from Ollama → fallback to note
  - Empty input → note
  - Strips markdown code fences from Ollama response
- [ ] **T2.2** Write `spec/services/intent_router_spec.rb` (~12 tests):
  - todo intent → creates Task (not Document)
  - Task created with correct title, description, due_date, due_time
  - Telegram reply "✅ Task added: ..."
  - event intent → creates Document with type note + #event tag
  - event intent → creates text block with body + due_at
  - event intent → sends Telegram reply with date
  - event creation failure → fallback to note
  - note intent → creates Document with text block + #telegram tag
  - note intent → sends "📝 Note saved"
  - Telegram send failure → logged, not raised
  - No Telegram reply when chat_id is blank
- [ ] **T2.3** Write `spec/services/telegram_message_handler_spec.rb` (~15 tests):
  - handle_text: calls IntentClassifierService + IntentRouter
  - handle_text: updates telegram_message_id on Document
  - handle_text: does not update telegram_message_id on Task
  - handle_photo: downloads largest photo, creates document with image block
  - handle_photo: auto-tags as telegram
  - handle_voice: creates document, enqueues TranscribeAudioJob
  - handle_audio: creates document, enqueues TranscribeAudioJob
  - handle_document: creates document with file block
  - handle_document: PDF → enqueues OcrPdfJob (if implemented)
  - Unsupported message type → error reply
  - Exception during handling → error reply, no crash
- [ ] **T2.4** Write `spec/services/google_calendar_service_spec.rb` (~12 tests):
  - Requires GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN
  - Raises on missing credentials
  - Full sync: fetches events, creates CalendarEvent records
  - Full sync: stores sync token for next run
  - Delta sync: uses stored sync token
  - Delta sync: handles token invalidation (410) → full resync
  - Upsert: updates existing event by google_event_id
  - Cancelled events: deletes local record
  - Multi-calendar: syncs all configured calendars
  - Auth error: raises (let job handle retry)
  - API error on one calendar: logs and continues others
  - upcoming_events class method: returns upcoming CalendarEvent records
- [ ] **T2.5** Run Phase 2 specs — verify all pass

### Phase 3: Job Specs

- [ ] **T3.1** Write `spec/jobs/google_calendar_sync_job_spec.rb` (~4 tests):
  - Calls GoogleCalendarService.new.sync!
  - Configured for 3 retries with polynomial backoff
  - Logs start and completion
  - Logs error and re-raises on failure
- [ ] **T3.2** Write `spec/jobs/send_event_reminder_job_spec.rb` (~8 tests):
  - Finds events via CalendarEvent.needs_reminder
  - Sends Telegram message with event title, time, duration, link
  - Updates event.reminded_at after sending
  - Does not send duplicate reminders (reminded_at already set)
  - No events starting soon → no Telegram call
  - Respects CALENDAR_REMINDER_MINUTES env var
  - Discards on error (no retry)
  - Telegram send failure → logged, other events still processed
- [ ] **T3.3** Write `spec/jobs/transcribe_audio_job_spec.rb` (~12 tests):
  - Finds document and audio block
  - Downloads audio from ActiveStorage
  - Calls Whisper API with audio file
  - Passes WHISPER_LANGUAGE when set, omits when not
  - Parses Whisper response (text + language)
  - Calls LLM correction (correct_transcription)
  - LLM correction failure → uses raw text
  - Calls IntentClassifierService on corrected text
  - Updates document title and document_type
  - Creates text block with text, raw_text, language
  - Applies intent-based tags
  - Sends Telegram notification
  - Whisper timeout → raises for retry
  - Creates error text block on failure
- [ ] **T3.4** Run Phase 3 specs — verify all pass

### Phase 4: API Request Specs

- [ ] **T4.1** Read existing Api controllers (tags, document_tags, calendar_event_tags, task_tags, telegram) to verify exact routes and response formats
- [ ] **T4.2** Write `spec/requests/api/tags_spec.rb` (~8 tests)
- [ ] **T4.3** Write `spec/requests/api/document_tags_spec.rb` (~6 tests)
- [ ] **T4.4** Write `spec/requests/api/calendar_event_tags_spec.rb` (~5 tests)
- [ ] **T4.5** Write `spec/requests/api/task_tags_spec.rb` (~5 tests)
- [ ] **T4.6** Write `spec/requests/api/telegram_spec.rb` (~6 tests)
- [ ] **T4.7** Run Phase 4 specs — verify all pass

### Phase 5: Web Request Specs

- [ ] **T5.1** Read web controllers (tasks, calendars, calendar_events, tags, dashboard, documents) to verify routes, params, response types
- [ ] **T5.2** Write `spec/requests/tasks_spec.rb` (~15 tests):
  - GET /tasks with each filter (today, upcoming, inbox, all, completed, overdue)
  - GET /tasks/new
  - POST /tasks (valid + invalid params)
  - GET /tasks/:id/edit
  - PATCH /tasks/:id (valid + invalid)
  - DELETE /tasks/:id
  - PATCH /tasks/:id/toggle
  - Tag filtering (?tags[]=...)
- [ ] **T5.3** Write `spec/requests/calendars_spec.rb` (~8 tests):
  - GET /calendar (default agenda view)
  - GET /calendar?view=week
  - GET /calendar?view=month
  - GET /calendar?date=2026-03-15
  - GET /calendar?filter=events / notes / tasks
  - GET /calendar/widget (Turbo Frame response)
- [ ] **T5.4** Write `spec/requests/calendar_events_spec.rb` (~10 tests):
  - GET /calendar/events/new
  - POST /calendar/events (valid + invalid)
  - GET /calendar/events/:id/edit (manual event)
  - GET /calendar/events/:id/edit (Google event → redirect)
  - PATCH /calendar/events/:id (manual)
  - PATCH /calendar/events/:id (Google → redirect)
  - DELETE /calendar/events/:id (manual)
  - DELETE /calendar/events/:id (Google → redirect)
- [ ] **T5.5** Write `spec/requests/tags_spec.rb` (~5 tests):
  - GET /tags (index, search with ?q=)
  - GET /tags/:name (show with documents + tasks)
  - GET /tags/:name (not found → 404)
- [ ] **T5.6** Write `spec/requests/dashboard_spec.rb` (~3 tests):
  - GET / (success, contains documents/events/tasks)
- [ ] **T5.7** Write `spec/requests/documents_web_spec.rb` (~5 tests):
  - DELETE /documents/:id (success, cascades blocks/tags)
  - DELETE /documents/:id (not found → 404)
  - Redirects to index after delete
- [ ] **T5.8** Run Phase 5 specs — verify all pass

### Phase 6: Finalization

- [ ] **T6.1** Run full spec suite (`bundle exec rspec`) — all specs green
- [ ] **T6.2** Check SimpleCov report — document coverage %
- [ ] **T6.3** Review and fix any flaky/timing-dependent tests
- [ ] **T6.4** Remove `test/` directory
- [ ] **T6.5** Update `.project/TEST_PLAN.md` to reflect new coverage state
