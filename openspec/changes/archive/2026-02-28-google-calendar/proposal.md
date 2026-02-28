## Why

The user's calendar events live in Google Calendar but Inbox has no awareness of them. The goal is to make Inbox the single attention center: see all upcoming events, and receive Telegram reminders before each event starts — without switching between apps.

## What Changes

- OAuth2 integration with Google Calendar API to sync events
- Calendar view in the Inbox web UI showing events from Google Calendar
- Background job that polls for upcoming events and sends Telegram reminders
- Events displayed alongside notes in a unified timeline

## Capabilities

### New Capabilities
- `google-calendar-sync`: OAuth2 flow to authorize Google Calendar access. Background job periodically fetches events from configured calendars. Events stored locally (or cached) for display in the web UI.
- `event-reminders`: A recurring job checks for events starting within the next N minutes and sends a Telegram message to the user. Configurable reminder lead time (e.g., 10 and 30 minutes before).
- `calendar-view`: New page (`/calendar`) in the web UI showing a timeline/list of upcoming events from Google Calendar alongside inbox documents.

### New Components
- `GoogleCalendarSyncJob` — fetches events via Google Calendar API v3 using stored OAuth tokens
- `SendEventReminderJob` — checks for events starting soon, sends Telegram notifications
- `CalendarEvent` model — stores synced events locally (title, start_time, end_time, google_event_id, calendar_id)
- `CalendarsController` — new web UI controller for calendar view
- OAuth callback flow — `config/routes.rb` + controller for Google OAuth2 callback
- `config/recurring.yml` — add sync job (every 15 min) and reminder check (every 1 min)

## Impact

- **Dependencies**: `google-api-client` gem (or `signet` for OAuth) + `google-apis-calendar_v3`
- **DB**: New `calendar_events` table migration
- **Credentials**: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN` in ENV
- **OAuth**: One-time manual OAuth2 flow to obtain refresh token; stored in ENV/credentials
- **SolidQueue**: Two new recurring job entries
- **No new Docker services** — pure Rails + Google API calls
