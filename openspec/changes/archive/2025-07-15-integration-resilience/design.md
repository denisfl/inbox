## Context

The project uses 5 different HTTP mechanisms across 4 external services:
- **Transcriber (Parakeet v3)**: `HTTP` gem with 600s timeout, has retry (3 attempts)
- **Telegram Bot API**: `telegram-bot-ruby` gem (no explicit timeout)
- **Telegram file downloads**: `open-uri` (no timeout)
- **Telegram notifications**: `Net::HTTP` (5s open, 10s read timeout)
- **Google Calendar**: `google-apis-calendar_v3` gem (default timeout), sync job has retry (3 attempts)

No centralized HTTP wrapper exists. Error handling is inconsistent.

## Goals / Non-Goals

**Goals:**
- Unified timeout/retry behavior across all external service calls
- Structured logging for all external interactions
- Health-check endpoint for monitoring
- Graceful degradation when services are unavailable
- Standardized job retry/discard configuration

**Non-Goals:**
- Replacing the `telegram-bot-ruby` or `google-apis-calendar_v3` gems (they handle their own HTTP internally)
- Circuit breaker pattern (over-engineering for single-user system)
- Request queuing or rate limiting on the outgoing side
- Metrics collection or dashboards (covered by `observability-status-page` change)

## Decisions

### 1. Wrapper around existing gems, not replacement
**Choice**: Create `ExternalServiceClient` for direct HTTP calls only (Transcriber, Telegram file downloads). For gem-based integrations (telegram-bot-ruby, google-apis), add timeout configuration at the gem level.
**Rationale**: The gems manage their own HTTP connections. Wrapping them would break their abstraction. Instead, configure their built-in timeout options.
**Alternative considered**: Replace all gems with direct HTTP calls — too much work, loses gem benefits (pagination, auth handling).

### 2. HTTP gem as the standard client
**Choice**: Use the `HTTP` gem (already in Gemfile) for all direct HTTP calls, replacing `open-uri` and `Net::HTTP` usage.
**Rationale**: `HTTP` gem has clean timeout API (`HTTP.timeout(connect: 5, read: 30)`), built-in follow redirects, and consistent error hierarchy. Already used by TranscribeAudioJob.

### 3. Service-specific timeout configuration via ENV
**Choice**: Default timeouts per service, overridable via ENV variables (`TRANSCRIBER_TIMEOUT`, `TELEGRAM_TIMEOUT`, `GOOGLE_CALENDAR_TIMEOUT`).
**Rationale**: Different services need different timeouts (transcription is slow, Telegram API is fast). ENV override allows tuning without code change.

### 4. Tagged logging, not external logging service
**Choice**: Use `Rails.logger.tagged("[service_name]")` for structured logging.
**Rationale**: Single-user system on Raspberry Pi. External logging services are overkill. Tagged logging searches well with `grep`. Already supported by Rails.

### 5. Health check probes with individual timeouts
**Choice**: `GET /api/health` checks each service with a 5s timeout, returns immediately without blocking.
**Rationale**: Health check should be fast. A slow/down service should not make the health endpoint slow. Individual timeouts ensure worst-case response time is bounded.

## Risks / Trade-offs

- **[Risk] Changing retry behavior surfaces hidden failures** → Services that previously hung silently will now log errors and retry. This is intentional but may generate noise initially. Mitigation: review logs after deployment.
- **[Risk] Timeout values too aggressive** → If Transcriber needs more than 600s for long audio, jobs will fail. Mitigation: ENV-configurable timeouts, documented defaults.
- **[Trade-off] No circuit breaker** → If Transcriber is down, every incoming voice message will still attempt 3 retries before failing. Acceptable for single-user volume.
- **[Risk] Health check hits external services** → The Transcriber `/health` endpoint is local (same Docker network). Google Calendar check would require an API call. Mitigation: for Google Calendar, merely verify credentials are present and token is not expired, don't make an actual API call.

## Migration Plan

1. Create `ExternalServiceClient` with timeout/retry/logging
2. Migrate `TelegramMessageHandler.download_file` from `open-uri` to `HTTP` gem with timeout
3. Migrate `SendEventReminderJob` from `Net::HTTP` to `ExternalServiceClient`
4. Add timeout configuration to `TranscribeAudioJob` (already uses HTTP gem — add structured logging)
5. Configure `google-apis-calendar_v3` timeout options in `GoogleCalendarService`
6. Standardize `retry_on` / `discard_on` in all jobs
7. Create `GET /api/health` endpoint
8. Deploy and monitor logs for first week

**Rollback**: Each step is independently reversible. Health check endpoint can be removed via route deletion.

## Open Questions

- Should the health check require authentication (API token) or be public?
- Should Google Calendar health be based on token validity check or actual API call?
- Should health check include backup status from `backup-system` change (cross-dependency)?
