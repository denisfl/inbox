## 1. ExternalServiceClient

- [x] 1.1 Create `app/services/external_service_client.rb` with `#get`, `#post` methods wrapping `HTTP` gem
- [x] 1.2 Implement configurable timeout per-service (defaults: transcriber=600s, telegram=30s, google_calendar=15s)
- [x] 1.3 Implement retry with exponential backoff (3 attempts, 1s/4s/9s) for transient errors (`Timeout::Error`, `Errno::ECONNREFUSED`, `HTTP::ConnectionError`)
- [x] 1.4 Skip retry for 4xx errors (except 429), respect `Retry-After` header for 429
- [x] 1.5 Add structured tagged logging: `Rails.logger.tagged("[service_name]")` for all calls (debug on success, error on failure)

## 2. Telegram Integration Hardening

- [x] 2.1 Replace `open-uri` in `TelegramMessageHandler.download_file` with `HTTP` gem call with 30s timeout
- [x] 2.2 Replace `Net::HTTP` in `SendEventReminderJob` with `ExternalServiceClient`
- [x] 2.3 Add explicit timeout to `telegram-bot-ruby` client configuration (if supported) or wrap bot API calls

## 3. Transcriber Integration Hardening

- [x] 3.1 Refactor `TranscribeAudioJob` to use `ExternalServiceClient` for structured logging and consistent error handling
- [x] 3.2 Keep 600s timeout (configurable via `TRANSCRIBER_TIMEOUT`)
- [x] 3.3 Ensure 413 (audio too long) is still treated as permanent failure (no retry)

## 4. Google Calendar Hardening

- [x] 4.1 Configure explicit timeout on `google-apis-calendar_v3` client in `GoogleCalendarService`
- [x] 4.2 Add tagged logging for sync operations (`[google_calendar]`)
- [x] 4.3 Verify `GoogleCalendarSyncJob` retry/discard configuration is correct

## 5. Job Retry Standardization

- [x] 5.1 Audit all SolidQueue jobs for `retry_on` / `discard_on` configuration
- [x] 5.2 Add `retry_on` with `wait: :polynomially_longer` for transient errors to all jobs missing it
- [x] 5.3 Add `discard_on` for permanent errors (invalid input, unsupported formats) where missing
- [x] 5.4 Document retry strategy in code comments for each job

## 6. Health Check Endpoint

- [x] 6.1 Create `Api::HealthController` with `show` action at `GET /api/health`
- [x] 6.2 Implement database health check (`ActiveRecord::Base.connection.execute("SELECT 1")`)
- [x] 6.3 Implement Transcriber health check (GET `{TRANSCRIBER_URL}/health` with 5s timeout)
- [x] 6.4 Implement Google Calendar health check (verify credentials present and token not expired)
- [x] 6.5 Return JSON with individual service statuses and overall status
- [x] 6.6 Add route in `config/routes.rb` under `api` namespace

## 7. Environment Configuration

- [x] 7.1 Add timeout ENV variables to `.env.example`: `TRANSCRIBER_TIMEOUT`, `TELEGRAM_TIMEOUT`, `GOOGLE_CALENDAR_TIMEOUT`
- [x] 7.2 Document default values and purpose of each variable

## 8. Tests

- [x] 8.1 Unit tests for `ExternalServiceClient` (timeout, retry, no-retry-on-4xx, logging, 429 handling)
- [x] 8.2 Unit tests for refactored `TelegramMessageHandler.download_file` (timeout, success, failure)
- [x] 8.3 Request spec for `GET /api/health` (all ok, some unavailable, db down)
- [x] 8.4 Verify existing job specs still pass after retry/discard standardization
