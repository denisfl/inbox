## 1. Database Migration

- [ ] 1.1 Generate model:
  ```bash
  rails generate model CalendarEvent \
    google_event_id:string \
    calendar_id:string \
    title:string \
    description:text \
    start_at:datetime \
    end_at:datetime \
    location:string \
    reminder_sent_at:datetime
  ```
- [ ] 1.2 Add unique index on `google_event_id` in the migration
- [ ] 1.3 Run migration on development; run on RPi after deploy

## 2. Gemfile

- [ ] 2.1 Add `gem 'google-apis-calendar_v3'` to `Gemfile` and run `bundle install`

## 3. One-Time OAuth2 Authorization (on developer machine)

- [ ] 3.1 Create a Google Cloud project; enable Calendar API; create OAuth2 credentials (Desktop app type)
- [ ] 3.2 Run the authorization script to get a refresh token:
  ```ruby
  # rails runner script
  require 'google/apis/calendar_v3'
  require 'googleauth'
  require 'googleauth/stores/file_token_store'

  client_id = Google::Auth::ClientId.new(ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'])
  scope = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY
  authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, nil)
  url = authorizer.get_authorization_url(base_url: 'urn:ietf:wg:oauth:2.0:oob')
  puts "Open: #{url}"
  print "Code: "
  code = gets.strip
  credentials = authorizer.get_and_store_credentials_from_code(user_id: 'default', code: code, base_url: 'urn:ietf:wg:oauth:2.0:oob')
  puts "Refresh token: #{credentials.refresh_token}"
  ```
- [ ] 3.3 Add `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`, `GOOGLE_CALENDAR_IDS` to `.env.production` on RPi

## 4. GoogleCalendarSyncJob

- [ ] 4.1 Create `app/jobs/google_calendar_sync_job.rb`:
  ```ruby
  class GoogleCalendarSyncJob < ApplicationJob
    queue_as :default

    def perform
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = credentials

      calendar_ids = ENV.fetch('GOOGLE_CALENDAR_IDS', 'primary').split(',').map(&:strip)

      calendar_ids.each do |cal_id|
        sync_calendar(service, cal_id)
      rescue StandardError => e
        Rails.logger.error("CalendarSync: calendar '#{cal_id}' failed: #{e.message}")
      end
    end

    private

    def credentials
      Google::Auth::UserRefreshCredentials.new(
        client_id: ENV.fetch('GOOGLE_CLIENT_ID'),
        client_secret: ENV.fetch('GOOGLE_CLIENT_SECRET'),
        refresh_token: ENV.fetch('GOOGLE_REFRESH_TOKEN'),
        scope: Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY
      )
    end

    def sync_calendar(service, cal_id)
      result = service.list_events(
        cal_id,
        single_events: true,
        order_by: 'startTime',
        time_min: Time.current.iso8601,
        time_max: 14.days.from_now.iso8601
      )

      synced_ids = []
      (result.items || []).each do |event|
        next if event.status == 'cancelled'
        start_at = event.start.date_time || DateTime.parse(event.start.date.to_s)
        end_at = event.end.date_time || DateTime.parse(event.end.date.to_s)

        CalendarEvent.find_or_initialize_by(google_event_id: event.id).tap do |ce|
          ce.assign_attributes(
            calendar_id: cal_id,
            title: event.summary.to_s,
            description: event.description.to_s,
            start_at: start_at,
            end_at: end_at,
            location: event.location.to_s
          )
          ce.save!
        end
        synced_ids << event.id
      end

      # Remove cancelled events (not returned by API anymore)
      CalendarEvent.where(calendar_id: cal_id)
                   .where.not(google_event_id: synced_ids)
                   .destroy_all
    end
  end
  ```

## 5. SendEventReminderJob

- [ ] 5.1 Create `app/jobs/send_event_reminder_job.rb`:
  ```ruby
  class SendEventReminderJob < ApplicationJob
    queue_as :default

    def perform
      lead_minutes = ENV.fetch('CALENDAR_REMINDER_MINUTES', '10').to_i
      window_start = Time.current
      window_end = lead_minutes.minutes.from_now

      events = CalendarEvent.where(
        start_at: window_start..window_end,
        reminder_sent_at: nil
      )

      return if events.none?

      bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])

      events.each do |event|
        text = "⏰ Скоро: <b>#{event.title}</b>\n"
        text += "🕐 #{event.start_at.strftime('%H:%M')}"
        text += " — #{event.location}" if event.location.present?
        bot.api.send_message(
          chat_id: ENV['TELEGRAM_ALLOWED_USER_ID'],
          text: text,
          parse_mode: 'HTML'
        )
        event.update_column(:reminder_sent_at, Time.current)
      rescue StandardError => e
        Rails.logger.error("Reminder failed for event #{event.id}: #{e.message}")
      end
    end
  end
  ```

## 6. Recurring Schedule

- [ ] 6.1 Add to `config/recurring.yml` under `production:`:
  ```yaml
    google_calendar_sync:
      class: GoogleCalendarSyncJob
      schedule: every 15 minutes
    send_event_reminder:
      class: SendEventReminderJob
      schedule: every minute
  ```

## 7. Routes & Controller

- [ ] 7.1 Add to `config/routes.rb`: `get '/calendar', to: 'calendars#index'`
- [ ] 7.2 Create `app/controllers/calendars_controller.rb`:
  ```ruby
  class CalendarsController < ApplicationController
    def index
      @events = CalendarEvent.where(start_at: Time.current..)
                             .order(:start_at)
                             .limit(50)
    end
  end
  ```
- [ ] 7.3 Create `app/views/calendars/index.html.erb` — grouped by day list of events

## 8. Environment Variables (on RPi)

- [ ] 8.1 Add to `.env.production`:
  ```
  GOOGLE_CLIENT_ID=...
  GOOGLE_CLIENT_SECRET=...
  GOOGLE_REFRESH_TOKEN=...
  GOOGLE_CALENDAR_IDS=primary
  CALENDAR_REMINDER_MINUTES=10
  ```
- [ ] 8.2 Add to `docker-compose.production.yml` environment for `web` and `worker`:
  ```yaml
  - GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
  - GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
  - GOOGLE_REFRESH_TOKEN=${GOOGLE_REFRESH_TOKEN}
  - GOOGLE_CALENDAR_IDS=${GOOGLE_CALENDAR_IDS}
  - CALENDAR_REMINDER_MINUTES=${CALENDAR_REMINDER_MINUTES}
  ```

## 9. Verification

- [ ] 9.1 Manually run sync: `rails runner 'GoogleCalendarSyncJob.perform_now'` → check `CalendarEvent.count`
- [ ] 9.2 Open `/calendar` in browser → verify events listed
- [ ] 9.3 Create a test event in Google Calendar starting in 5 min → verify Telegram reminder arrives
- [ ] 9.4 Confirm reminder sent only once (check `reminder_sent_at` is set)
