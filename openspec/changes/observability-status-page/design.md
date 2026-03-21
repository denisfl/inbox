## Context

The app runs on a Raspberry Pi with no visibility into system health besides SSH. External integrations (Transcriber, Google Calendar, Telegram) can fail silently. SolidQueue manages background jobs but there's no dashboard for queue health or failed jobs. The existing `/up` route only checks if Rails boots.

## Decisions

### 1. Admin namespace with HTTP Basic Auth

**Rationale**: Rails built-in `http_basic_authenticate_with` requires zero dependencies. ENV-configured credentials (`ADMIN_USER`, `ADMIN_PASSWORD`) keep secrets out of code. A dedicated `Admin::StatusController` avoids polluting existing controllers.

**Trade-off**: No session-based login, but acceptable for a single-user status page.

### 2. Direct SolidQueue table queries for job stats

**Rationale**: SolidQueue stores job data in `solid_queue_jobs`, `solid_queue_failed_executions`, and `solid_queue_ready_executions` tables. Querying these directly (via `SolidQueue::Job`, `SolidQueue::FailedExecution`) is the simplest approach — no additional gems or APIs needed.

**Alternative rejected**: MissionControl-Jobs dashboard — too heavy for this use case, adds dependency.

### 3. Health check probes with timeout

**Rationale**: Each integration gets a lightweight probe:

- **Database**: `ActiveRecord::Base.connection.execute("SELECT 1")` — verifies SQLite is accessible
- **Transcriber**: HTTP GET to `TRANSCRIBER_URL/health` with 3s timeout — the Parakeet service already exposes this endpoint
- **Google Calendar**: Check `GOOGLE_CALENDAR_ID` ENV is set + last successful sync time from `calendar_events` table — avoids making an API call on every status page load

**Design**: A `StatusChecker` service returns a hash of `{ name: :ok | :unavailable, details: ... }` for each probe.

### 4. ErrorNotifierJob — fire-and-forget Telegram alerts

**Rationale**: Reuse existing `Telegram::Bot::Client` pattern already in `TelegramMessageHandler`, `TranscribeAudioJob`, and `TelegramController`. A dedicated job prevents notification failures from affecting the caller.

**Key rule**: `ErrorNotifierJob` itself must NOT retry on failure (avoids cascade). It logs at ERROR level if Telegram send fails, then silently discards.

**Trigger points**: Called from `ApplicationJob`'s `after_discard` / rescue hooks when a job exhausts all retries.

### 5. Slow operation instrumentation via `ActiveSupport::Notifications`

**Rationale**: Rails' built-in instrumentation is zero-dependency and composable. Services wrap external calls in `ActiveSupport::Notifications.instrument("external_service.inbox", ...)` blocks. A subscriber checks duration against `SLOW_OPERATION_THRESHOLD` (default 5s) and logs a warning.

**Alternative rejected**: Custom timing wrapper — less standard, harder to extend.

### 6. Status page rendered as plain HTML (no JS)

**Rationale**: The status page is a read-only diagnostic tool. Server-rendered HTML with Tailwind keeps it simple and fast. No Stimulus controllers or Turbo frames needed.

## Risks

1. **SolidQueue internal API stability**: Direct table queries may break on SolidQueue upgrades. Mitigate by using SolidQueue's public model classes and pinning the gem version.
2. **Health check probe latency**: If Transcriber is down, the 3s timeout adds to page load. Mitigate with a note in the UI that checks may take a few seconds.
3. **Telegram notification flood**: If many jobs fail simultaneously, many notifications fire. Mitigate by rate-limiting (e.g., max 1 notification per error class per 5 minutes) tracked in-memory.

## Implementation order

1. `StatusChecker` service (health probes)
2. `Admin::StatusController` with HTTP Basic Auth + route
3. Status page view (integrations, queue stats, system metrics)
4. `ErrorNotifierJob` (Telegram alerts on critical failures)
5. `ApplicationJob` hooks for failure notification
6. Slow operation instrumentation subscriber
7. Tests for all components
