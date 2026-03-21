## Why

The project integrates with 4 external services (Telegram Bot API, Transcriber/Parakeet, Google Calendar, and previously Ollama/Whisper). Each uses a different HTTP library (telegram-bot-ruby, HTTP gem, Net::HTTP, open-uri, google-apis gem) with inconsistent timeout and retry behavior. Some calls have no timeout at all (Telegram file downloads, Google OAuth2). If any service becomes unavailable, the failure mode is unclear — requests may hang indefinitely or crash without actionable error messages.

## What Changes

- New `ExternalServiceClient` wrapper providing standardized timeout, retry with exponential backoff, and structured error logging for all HTTP calls
- Explicit timeout configuration for all external service calls (currently missing for Telegram file downloads, Google Calendar API)
- `retry_on` / `discard_on` standardization across all SolidQueue jobs
- Structured logging via `ActiveSupport::TaggedLogging` with `[service_name]` tags for all external calls
- New `GET /api/health` endpoint returning status of each integration
- Graceful degradation: unavailability of one service does not affect others

## Capabilities

### New Capabilities
- `external-service-client`: Centralized HTTP client wrapper with configurable timeout, retry, and structured logging
- `health-check-api`: `GET /api/health` endpoint returning status of each integration (Transcriber, Telegram, Google Calendar, database)

### Modified Capabilities
<!-- No existing spec-level capability changes -->

## Impact

- **Modified files**: All jobs and services making HTTP calls (`transcribe_audio_job.rb`, `send_event_reminder_job.rb`, `process_telegram_update_job.rb`, `google_calendar_sync_job.rb`, `telegram_message_handler.rb`, `google_calendar_service.rb`)
- **New files**: `app/services/external_service_client.rb`, `app/controllers/api/health_controller.rb`
- **Dependencies**: No new gems — `HTTP` gem is already in Gemfile
- **APIs**: New `GET /api/health` endpoint
- **Risk**: Changing timeout/retry behavior of existing integrations could surface previously-masked failures
