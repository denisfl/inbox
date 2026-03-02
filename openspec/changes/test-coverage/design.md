---
id: test-coverage
artifact: design
---

## Architecture

### Test Infrastructure Changes

#### Gemfile additions (test group)

```ruby
group :test do
  gem "webmock", "~> 3.23"   # Stub HTTP requests to Ollama, Whisper, Telegram, Google
end
```

#### spec/rails_helper.rb changes

```ruby
# At top of file, before anything else:
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/db/'
  add_group 'Models',      'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services',    'app/services'
  add_group 'Jobs',        'app/jobs'
  add_group 'Helpers',     'app/helpers'
end

# After require 'rspec/rails':
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)
```

#### Shared Contexts (spec/support/)

```ruby
# spec/support/api_auth.rb
RSpec.shared_context 'api_auth' do
  let(:api_token) { ENV['API_TOKEN'] || 'development_token' }
  let(:api_headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Token token=#{api_token}"
    }
  end
end

# spec/support/web_auth.rb
RSpec.shared_context 'web_auth' do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('WEB_PASSWORD', anything).and_return('test_password')
    # HTTP Basic Auth credentials
    @credentials = ActionController::HttpAuthentication::Basic.encode_credentials('_', 'test_password')
  end

  let(:auth_headers) { { 'HTTP_AUTHORIZATION' => @credentials } }
end

# spec/support/telegram_stub.rb
RSpec.shared_context 'telegram_stub' do
  before do
    stub_request(:post, /api.telegram.org/).to_return(status: 200, body: '{"ok":true}')
  end
end

# spec/support/ollama_stub.rb
RSpec.shared_context 'ollama_stub' do
  let(:ollama_base_url) { ENV.fetch('OLLAMA_BASE_URL', 'http://ollama:11434') }

  def stub_ollama_classify(intent: 'note', confidence: 0.9, title: 'Test', due_at: nil)
    response_json = { intent: intent, confidence: confidence, title: title, due_at: due_at }.to_json
    stub_request(:post, "#{ollama_base_url}/api/generate")
      .to_return(status: 200, body: { response: response_json }.to_json)
  end

  def stub_ollama_correction(corrected_text)
    stub_request(:post, "#{ollama_base_url}/api/generate")
      .to_return(status: 200, body: { response: corrected_text }.to_json)
  end

  def stub_ollama_error
    stub_request(:post, "#{ollama_base_url}/api/generate")
      .to_return(status: 500, body: 'Internal Server Error')
  end
end
```

### New Factories

```ruby
# spec/factories/calendar_events.rb
FactoryBot.define do
  factory :calendar_event do
    title { Faker::Lorem.sentence(word_count: 3) }
    starts_at { 1.hour.from_now }
    ends_at { 2.hours.from_now }
    status { 'confirmed' }
    source { 'manual' }
    google_event_id { "manual-#{SecureRandom.uuid}" }
    all_day { false }

    trait :google do
      source { 'google' }
      google_event_id { "google_#{SecureRandom.hex(10)}" }
      html_link { "https://calendar.google.com/event/#{google_event_id}" }
    end

    trait :all_day do
      all_day { true }
      starts_at { Date.current.beginning_of_day }
      ends_at { Date.current.end_of_day }
    end

    trait :today do
      starts_at { Time.current.change(hour: 14) }
      ends_at { Time.current.change(hour: 15) }
    end

    trait :tomorrow do
      starts_at { 1.day.from_now.change(hour: 10) }
      ends_at { 1.day.from_now.change(hour: 11) }
    end

    trait :past do
      starts_at { 1.day.ago }
      ends_at { 1.day.ago + 1.hour }
    end

    trait :needs_reminder do
      starts_at { 15.minutes.from_now }
      ends_at { 75.minutes.from_now }
      reminded_at { nil }
    end

    trait :already_reminded do
      starts_at { 15.minutes.from_now }
      reminded_at { 5.minutes.ago }
    end

    trait :cancelled do
      status { 'cancelled' }
    end
  end
end

# spec/factories/calendar_event_tags.rb
FactoryBot.define do
  factory :calendar_event_tag do
    association :calendar_event
    association :tag
  end
end

# spec/factories/tasks.rb
FactoryBot.define do
  factory :task do
    title { Faker::Lorem.sentence(word_count: 3) }
    priority { 'mid' }
    completed { false }

    trait :pinned do
      priority { 'pinned' }
    end

    trait :high do
      priority { 'high' }
    end

    trait :low do
      priority { 'low' }
    end

    trait :completed do
      completed { true }
      completed_at { Time.current }
    end

    trait :due_today do
      due_date { Date.current }
    end

    trait :due_tomorrow do
      due_date { Date.current + 1.day }
    end

    trait :overdue do
      due_date { Date.current - 2.days }
    end

    trait :inbox do
      due_date { nil }
      priority { 'mid' }
    end

    trait :recurring_daily do
      recurrence_rule { 'daily' }
      due_date { Date.current }
    end

    trait :recurring_weekly do
      recurrence_rule { 'weekly' }
      due_date { Date.current }
    end

    trait :with_tags do
      after(:create) do |task|
        tag = create(:tag)
        create(:task_tag, task: task, tag: tag)
      end
    end
  end
end

# spec/factories/task_tags.rb
FactoryBot.define do
  factory :task_tag do
    association :task
    association :tag
  end
end
```

---

## Spec File Plan

### Phase 1 — Models (foundational, no external deps)

| File | Tests | Est. `it` blocks |
|------|-------|---------|
| `spec/models/calendar_event_spec.rb` | Validations, scopes (confirmed, google, manual, upcoming, today, tomorrow, this_week, in_range, needs_reminder), callbacks (assign_local_uid, normalize_event_times), instance methods (duration_minutes, duration_label, display_color, time_label, local?) | ~25 |
| `spec/models/calendar_event_tag_spec.rb` | Associations, uniqueness validation | ~3 |
| `spec/models/task_spec.rb` | Validations, scopes (active, completed, pinned, today, upcoming, inbox, overdue, with_due_date, tagged_with, in_date_range, ordered), instance methods (complete!, uncomplete!, toggle!, overdue?, due_today?, recurring?), recurrence spawning | ~30 |
| `spec/models/task_tag_spec.rb` | Associations, uniqueness validation | ~3 |

### Phase 2 — Services (stubbed external APIs)

| File | Tests | Est. `it` blocks |
|------|-------|---------|
| `spec/services/intent_classifier_service_spec.rb` | Classification for todo/event/note, confidence threshold, title extraction, due_at parsing, Ollama timeout fallback, HTTP error fallback, malformed JSON fallback, empty input | ~15 |
| `spec/services/intent_router_spec.rb` | create_todo→Task, create_event→Document with tags, create_note→Document with tags, Telegram reply, event creation fallback to note, Telegram send failure logging | ~12 |
| `spec/services/telegram_message_handler_spec.rb` | handle_text (calls IntentClassifier+Router), handle_photo, handle_voice (enqueues TranscribeAudioJob), handle_document (PDF detection), unsupported type, error handling | ~15 |
| `spec/services/google_calendar_service_spec.rb` | Full sync, delta sync, event upsert, cancelled event deletion, multi-calendar, auth error, API error recovery, sync token persistence | ~12 |

### Phase 3 — Jobs (stubbed services)

| File | Tests | Est. `it` blocks |
|------|-------|---------|
| `spec/jobs/google_calendar_sync_job_spec.rb` | Delegates to GoogleCalendarService#sync!, retry behavior, error logging | ~4 |
| `spec/jobs/send_event_reminder_job_spec.rb` | Finds needs_reminder events, sends Telegram message, updates reminded_at, skips already reminded, no events = no action, Telegram failure doesn't crash | ~8 |
| `spec/jobs/transcribe_audio_job_spec.rb` | Downloads audio from ActiveStorage, calls Whisper API, LLM correction, intent classification, updates document title/type, creates text block, handles timeout, handles transcription failure | ~12 |

### Phase 4 — Request Specs (API controllers)

| File | Tests | Est. `it` blocks |
|------|-------|---------|
| `spec/requests/api/tags_spec.rb` | GET /api/tags (list), GET /api/tags/:id (show), POST (create), PATCH (update), DELETE, auth required | ~8 |
| `spec/requests/api/document_tags_spec.rb` | POST /api/documents/:id/tags (add tag), DELETE (remove tag), duplicate prevention, auth | ~6 |
| `spec/requests/api/calendar_event_tags_spec.rb` | POST add tag, DELETE remove tag, auth | ~5 |
| `spec/requests/api/task_tags_spec.rb` | POST add tag, DELETE remove tag, auth | ~5 |
| `spec/requests/api/telegram_spec.rb` | POST /api/telegram/webhook, secret token validation, message routing, invalid payload | ~6 |

### Phase 5 — Request Specs (Web controllers)

| File | Tests | Est. `it` blocks |
|------|-------|---------|
| `spec/requests/tasks_spec.rb` | GET /tasks (all filters: today/upcoming/inbox/all/completed/overdue), GET /tasks/new, POST /tasks, GET /tasks/:id/edit, PATCH /tasks/:id, DELETE /tasks/:id, PATCH /tasks/:id/toggle, tag filtering | ~15 |
| `spec/requests/calendars_spec.rb` | GET /calendar (agenda/week/month views, date ranges, filters), GET /calendar/widget (today events/tasks) | ~8 |
| `spec/requests/calendar_events_spec.rb` | GET /calendar/events/new, POST /calendar/events, GET /calendar/events/:id/edit, PATCH /calendar/events/:id, DELETE /calendar/events/:id, cannot edit/delete Google events | ~10 |
| `spec/requests/tags_spec.rb` | GET /tags (index, search), GET /tags/:name (show with documents + tasks) | ~5 |
| `spec/requests/dashboard_spec.rb` | GET / (dashboard data) | ~3 |
| `spec/requests/documents_spec.rb` | DELETE /documents/:id (destroy with confirmation, cascade blocks/tags/blobs), 404 for missing | ~5 |

### Phase 6 — Infrastructure

| Action | Details |
|--------|---------|
| Activate SimpleCov | Add `require 'simplecov'; SimpleCov.start 'rails'` at top of `spec/rails_helper.rb` |
| Configure WebMock | Add `require 'webmock/rspec'` and disable net connect |
| Uncomment support dir | Uncomment `Rails.root.glob('spec/support/**/*.rb')...` in rails_helper.rb |
| Remove `test/` directory | Delete empty Minitest skeleton |

---

## Estimated Totals

| Phase | Files | Est. Tests |
|-------|-------|------------|
| Phase 1: Models | 4 | ~61 |
| Phase 2: Services | 4 | ~54 |
| Phase 3: Jobs | 3 | ~24 |
| Phase 4: API requests | 5 | ~30 |
| Phase 5: Web requests | 6 | ~46 |
| Phase 6: Infra | 3 support files | — |
| **Total new** | **25 spec files** | **~215** |
| Existing specs | 12 | 121 |
| **Grand total** | **37 spec files** | **~336** |

---

## External Dependency Stubbing Strategy

| External System | Stub Method | Notes |
|-----------------|-------------|-------|
| Ollama (LLM) | WebMock | Stub POST to /api/generate, return mock JSON |
| Whisper (STT) | WebMock | Stub POST to /transcribe, return mock transcription |
| Telegram Bot API | WebMock | Stub all POST to api.telegram.org |
| Google Calendar API | WebMock or mock object | Mock `Google::Apis::CalendarV3::CalendarService` methods |
| ActiveStorage (file download) | Fixture files | Use test fixtures in spec/fixtures/files/ |

---

## Priority Order

1. **Phase 1** (Models) — no deps, fast, validates data layer
2. **Phase 2** (Services) — core business logic with stubbed externals
3. **Phase 3** (Jobs) — async processing with stubbed services
4. **Phase 4** (API requests) — API contract verification
5. **Phase 5** (Web requests) — web UI flow verification
6. **Phase 6** (Infra) — coverage reporting, cleanup
