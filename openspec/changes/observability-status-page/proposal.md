## Why

Running on a Raspberry Pi, there's no visibility into system health without SSH access. When a service degrades (Transcriber goes down, jobs fail silently), there's no way to know until functionality visibly breaks. Critical errors should proactively notify via Telegram.

## What Changes

- New `/admin/status` page (behind HTTP Basic Auth) showing integration statuses, job queue sizes, document counts, last backup, last calendar sync
- `ErrorNotifierJob` that sends Telegram messages on critical failures (failed jobs after all retries, prolonged service unavailability)
- Performance logging for slow operations (>5s threshold)

## Capabilities

### New Capabilities

- `admin-status-page`: Web dashboard showing system health, queue depths, and integration statuses
- `error-notification`: Telegram notifications for critical system failures

### Modified Capabilities

<!-- No existing spec changes -->

## Impact

- **New files**: `app/controllers/admin/status_controller.rb`, `app/views/admin/status/show.html.erb`, `app/jobs/error_notifier_job.rb`
- **Config**: `config/routes.rb` (add `/admin/status` route with HTTP Basic Auth)
- **Dependencies**: None (uses existing Telegram integration for notifications)
