# frozen_string_literal: true

# rake google_calendar:authorize  — perform one-time OAuth2 flow to obtain refresh_token
# rake google_calendar:sync       — trigger a manual sync
# rake google_calendar:reset      — clear syncTokens (next sync will be full for all calendars)
# rake google_calendar:status     — show event counts

namespace :google_calendar do
  desc "One-time OAuth2 flow — opens browser, prompts for auth code, prints refresh_token"
  task authorize: :environment do
    require "googleauth"

    client_id     = ENV.fetch("GOOGLE_CLIENT_ID") { abort "GOOGLE_CLIENT_ID env var is required" }
    client_secret = ENV.fetch("GOOGLE_CLIENT_SECRET") { abort "GOOGLE_CLIENT_SECRET env var is required" }

    scope = "https://www.googleapis.com/auth/calendar.readonly"

    client_config = {
      "installed" => {
        "client_id"     => client_id,
        "client_secret" => client_secret,
        "redirect_uris" => [ "urn:ietf:wg:oauth:2.0:oob" ],
        "auth_uri"      => "https://accounts.google.com/o/oauth2/auth",
        "token_uri"     => "https://oauth2.googleapis.com/token"
      }
    }

    client_secrets = Google::Auth::ClientId.from_hash(client_config)
    callback_uri   = "urn:ietf:wg:oauth:2.0:oob"

    authorizer = Google::Auth::UserAuthorizer.new(client_secrets, scope, nil)
    url = authorizer.get_authorization_url(base_url: callback_uri)

    puts ""
    puts "=" * 70
    puts "  GOOGLE CALENDAR AUTHORIZATION"
    puts "=" * 70
    puts ""
    puts "  1. Open the following URL in your browser:"
    puts ""
    puts "     #{url}"
    puts ""
    puts "  2. Sign in with your Google account and grant access."
    puts "  3. Copy the authorization code shown and paste it below."
    puts ""
    print "  Enter authorization code: "
    code = $stdin.gets.strip

    require "net/http"
    require "json"

    uri = URI("https://oauth2.googleapis.com/token")
    response = Net::HTTP.post_form(uri, {
      code:          code,
      client_id:     client_id,
      client_secret: client_secret,
      redirect_uri:  callback_uri,
      grant_type:    "authorization_code"
    })
    body = JSON.parse(response.body)

    if body["refresh_token"]
      puts ""
      puts "=" * 70
      puts "  SUCCESS! Add the following to your .env.production on RPi:"
      puts "=" * 70
      puts ""
      puts "  GOOGLE_CLIENT_ID=#{client_id}"
      puts "  GOOGLE_CLIENT_SECRET=#{client_secret}"
      puts "  GOOGLE_REFRESH_TOKEN=#{body['refresh_token']}"
      puts "  GOOGLE_CALENDAR_IDS=primary"
      puts ""
      puts "  Then run:  bin/rails google_calendar:sync"
      puts ""
    else
      puts "  ERROR: #{body.inspect}"
      abort "Failed to obtain refresh_token"
    end
  end

  desc "Trigger a manual Google Calendar sync (all calendars in GOOGLE_CALENDAR_IDS)"
  task sync: :environment do
    puts "Starting Google Calendar sync..."
    GoogleCalendarService.new.sync!
    puts "Sync complete. Events: #{CalendarEvent.count}"
  end

  desc "Clear all stored syncTokens (next sync will be a full reload for every calendar)"
  task reset: :environment do
    tokens = Dir[Rails.root.join("tmp", "google_sync_token_*.txt").to_s]
    # Also handle old single-calendar token file
    tokens += [ Rails.root.join("tmp", "google_sync_token.txt").to_s ]
    deleted = tokens.select { |p| File.exist?(p) }.each { |p| File.delete(p) }
    if deleted.any?
      puts "Deleted #{deleted.size} syncToken file(s). Next sync will be a full load."
    else
      puts "No syncToken files found."
    end
  end

  desc "Show CalendarEvent counts"
  task status: :environment do
    total     = CalendarEvent.count
    confirmed = CalendarEvent.confirmed.count
    upcoming  = CalendarEvent.upcoming.count
    tokens    = Dir[Rails.root.join("tmp", "google_sync_token_*.txt").to_s].map { |p| File.basename(p) }

    puts ""
    puts "CalendarEvent status:"
    puts "  Total events   : #{total}"
    puts "  Confirmed      : #{confirmed}"
    puts "  Upcoming       : #{upcoming}"
    puts "  syncToken files: #{tokens.any? ? tokens.join(', ') : 'none'}"
    last = CalendarEvent.order(synced_at: :desc).first
    puts "  Last synced    : #{last&.synced_at || 'never'}"
    puts ""
    puts "  Configured calendar IDs (GOOGLE_CALENDAR_IDS):"
    ENV.fetch("GOOGLE_CALENDAR_IDS", "primary").split(",").map(&:strip).each do |id|
      count = CalendarEvent.where(google_calendar_id: id).count
      puts "    #{id}  →  #{count} events"
    end
    puts ""
  end
end
