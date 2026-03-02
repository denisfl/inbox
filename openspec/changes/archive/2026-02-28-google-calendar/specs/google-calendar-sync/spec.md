## ADDED Requirements

### Requirement: Google Calendar events synced to local database
The system SHALL periodically fetch events from configured Google Calendars and store them locally.

#### Scenario: Events fetched and stored
- **GIVEN** `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`, and `GOOGLE_CALENDAR_IDS` are set
- **WHEN** `GoogleCalendarSyncJob` runs
- **THEN** all events from the configured calendars starting within the next 14 days SHALL be fetched via Google Calendar API v3
- **AND** each event SHALL be upserted into `calendar_events` table (insert or update by `google_event_id`)

#### Scenario: Cancelled events removed
- **GIVEN** an event previously synced is cancelled in Google Calendar
- **WHEN** `GoogleCalendarSyncJob` runs
- **THEN** the local `CalendarEvent` record SHALL be deleted

#### Scenario: Sync runs every 15 minutes
- **WHEN** the Rails app is running in production
- **THEN** `GoogleCalendarSyncJob` SHALL run automatically every 15 minutes via SolidQueue recurring

#### Scenario: Sync failure does not crash — logged only
- **GIVEN** the Google API returns an error (network issue, token expired)
- **WHEN** `GoogleCalendarSyncJob` runs
- **THEN** the error SHALL be logged and the job SHALL complete without raising
- **AND** existing local events SHALL remain unchanged

### Requirement: Calendar events viewable in web UI
- **WHEN** the user navigates to `/calendar`
- **THEN** a list of upcoming events (next 7 days) SHALL be displayed, sorted by `start_at`
- **AND** each event SHALL show: title, date/time, location (if present)
