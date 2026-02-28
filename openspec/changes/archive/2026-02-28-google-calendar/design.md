## Context

The user's calendar events are managed in Google Calendar. Inbox should display upcoming events and send Telegram reminders — making it unnecessary to check the calendar app separately. The integration uses Google Calendar API v3 with OAuth2 (offline access / refresh token).

The system has no existing calendar functionality. This story adds a full sync pipeline: OAuth2 authorization → event storage → reminder dispatch → web UI view.

## Goals / Non-Goals

**Goals:**
- OAuth2 integration with Google Calendar API (one-time manual authorization)
- Periodic sync of events from selected Google Calendars (every 15 minutes)
- Telegram reminder notifications at configurable lead times before event start (e.g., 10 min before)
- Web UI page `/calendar` showing upcoming events
- Events stored locally in `calendar_events` table for fast querying

**Non-Goals:**
- Two-way sync (writing events to Google Calendar from Inbox) — read-only in v1
- Multiple Google accounts
- Recurring event expansion beyond what the API returns
- Mobile push notifications (Telegram only)

## Decisions

### Decision: `google-apis-calendar_v3` gem (official Google client)

Official Ruby client for Google Calendar API v3. Handles OAuth2 token refresh automatically via `Google::Auth::UserRefreshCredentials`.

### Decision: Offline OAuth2 → refresh token stored in ENV

One-time manual OAuth2 flow generates a refresh token. Stored as `GOOGLE_REFRESH_TOKEN` in `.env.production`. The gem refreshes access tokens automatically — no user interaction required after initial setup.

**ENV vars needed:**
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REFRESH_TOKEN`
- `GOOGLE_CALENDAR_IDS` — comma-separated calendar IDs to sync (e.g., `primary,work@example.com`)

### Decision: `CalendarEvent` model (local cache)

Events stored in `calendar_events` table: `google_event_id`, `calendar_id`, `title`, `description`, `start_at`, `end_at`, `location`, `reminder_sent_at`. Local cache allows fast querying without hitting Google API on every page load.

**Sync strategy:** full sync with `timeMin: Time.current`, `timeMax: 14.days.from_now`. Upsert by `google_event_id`.

### Decision: Reminder check every 1 minute via SolidQueue recurring

`SendEventReminderJob` runs every minute, queries events where:
- `start_at` is within the next 10 minutes
- `reminder_sent_at IS NULL`

Sends Telegram message and sets `reminder_sent_at = Time.current`.

Configurable lead time via `CALENDAR_REMINDER_MINUTES` ENV (default: 10).

### Decision: Calendar web UI as a simple list (not a grid calendar)

`/calendar` shows upcoming events for the next 7 days as a chronological list — simpler to implement than a grid, works well on mobile.

## Risks / Trade-offs

- **Risk:** Google API rate limits (10 req/user/sec) → **Mitigation:** 15-min sync interval is far within limits.
- **Risk:** Refresh token expiry (if app is in "Testing" mode and token > 7 days) → **Mitigation:** Publish app to avoid 7-day limit, or re-authorize periodically.
- **Risk:** One-minute recurring job overhead → **Mitigation:** Query is a single indexed DB lookup; negligible overhead.
- **Risk:** `GOOGLE_REFRESH_TOKEN` in ENV is a secret → **Mitigation:** Same security model as `TELEGRAM_BOT_TOKEN` — stored in `.env.production` on RPi (gitignored).

## Migration Plan

1. `rails generate model CalendarEvent google_event_id:string:uniq calendar_id:string title:string description:text start_at:datetime end_at:datetime location:string reminder_sent_at:datetime`
2. Add `gem 'google-apis-calendar_v3'` to Gemfile
3. Implement `GoogleCalendarSyncJob`
4. Implement `SendEventReminderJob`
5. Add both to `config/recurring.yml`
6. Add `CalendarsController` + route + view
7. One-time manual OAuth2 flow to get refresh token
8. Deploy
