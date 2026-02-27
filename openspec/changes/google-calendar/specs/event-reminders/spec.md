## ADDED Requirements

### Requirement: Telegram reminder sent before event starts
The system SHALL send a Telegram reminder to the user before each calendar event begins.

#### Scenario: Reminder sent N minutes before event
- **GIVEN** a `CalendarEvent` with `start_at` within the next `CALENDAR_REMINDER_MINUTES` minutes (default: 10)
- **AND** `reminder_sent_at` is NULL
- **WHEN** `SendEventReminderJob` runs
- **THEN** a Telegram message SHALL be sent to `TELEGRAM_ALLOWED_USER_ID` with event title, time, and location
- **AND** `reminder_sent_at` SHALL be set to the current time

#### Scenario: Reminder sent only once per event
- **GIVEN** a reminder was already sent for an event (`reminder_sent_at IS NOT NULL`)
- **WHEN** `SendEventReminderJob` runs again
- **THEN** no duplicate reminder SHALL be sent

#### Scenario: No events starting soon — no action
- **GIVEN** no events are starting within the reminder window
- **WHEN** `SendEventReminderJob` runs
- **THEN** no Telegram message SHALL be sent

#### Scenario: Reminder job runs every minute
- **WHEN** the Rails app is running in production
- **THEN** `SendEventReminderJob` SHALL be scheduled to run every minute via SolidQueue recurring

### Requirement: Reminder lead time is configurable
- **WHEN** `CALENDAR_REMINDER_MINUTES=30` is set
- **THEN** reminders SHALL be sent 30 minutes before events
- **WHEN** `CALENDAR_REMINDER_MINUTES` is not set
- **THEN** the default lead time of 10 minutes SHALL be used
