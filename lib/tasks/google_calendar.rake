# frozen_string_literal: true

# rake google_calendar:authorize  — perform one-time OAuth2 flow to obtain refresh_token
# rake google_calendar:sync       — trigger a manual sync
# rake google_calendar:reset      — clear syncToken (next sync will be full)
# rake google_calendar:status     — show event counts

namespace :google_calendar do
  desc "One-time OAuth2 flow — opens browser, prompts for auth code, prints refresh_token"
  task authorize: :environment do
    require "googleauth"
    require "googleauth/stores/file_token_store"

    creds = Rails.application.credentials.google_calendar || {}
    client_id     = creds[:client_id]     or abort "google_calendar.client_id missing from credentials"
    client_secret = creds[:client_secret] or abort "google_calendar.client_secret missing from credentials"

    scope = "https://www.googleapis.com/auth/calendar.readonly"

    # Build the authorization URL
    client_config = {
      "installed" => {
        "client_id"                   => client_id,
        "client_secret"               => client_secret,
        "redirect_uris"               => ["urn:ietf:wg:oauth:2.0:oob"],
        "auth_uri"                    => "https://accounts.google.com/o/oauth2/auth",
        "token_uri"                   => "https://oauth2.googleapis.com/token"
      }
    }

    client_secrets = Google::Auth::ClientId.from_hash(client_config)
    callback_uri   = "urn:ietf:wg:oauth:2.0:oob"

    authorizer = Google::Auth::UserAuthorizer.new(
      client_secrets,
      scope,
      nil # no token store — we'll handle it manually
    )

    # Build the auth URL
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

    # Exchange code for tokens using Google's token endpoint directly
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
      puts "  SUCCESS! Add the following to your Rails credentials:"
      puts "  (run: EDITOR=nano bin/rails credentials:edit)"
      puts "=" * 70
      puts ""
      puts "  google_calendar:"
      puts "    client_id: #{client_id}"
      puts "    client_secret: #{client_secret}"
      puts "    refresh_token: #{body['refresh_token']}"
      puts "    calendar_id: primary"
      puts ""
    else
      puts "  ERROR: #{body.inspect}"
      abort "Failed to obtain refresh_token"
    end
  end

  desc "Trigger a manual Google Calendar sync"
  task sync: :environment do
    puts "Starting Google Calendar sync..."
    GoogleCalendarService.new.sync!
    puts "Sync complete. Events: #{CalendarEvent.count}"
  end

  desc "Clear the stored syncToken (next sync will be a full reload)"
  task reset: :environment do
    token_path = Rails.root.join("tmp", "google_sync_token.txt")
    if File.exist?(token_path)
      File.delete(token_path)
      puts "syncToken cleared. Next sync will be a full load."
    else
      puts "No syncToken found."
    end
  end

  desc "Show CalendarEvent counts"
  task status: :environment do
    total     = CalendarEvent.count
    confirmed = CalendarEvent.confirmed.count
    upcoming  = CalendarEvent.upcoming.count
    token     = File.exist?(Rails.root.join("tmp", "google_sync_token.txt")) ? "present" : "missing"

    puts ""
    puts "CalendarEvent status:"
    puts "  Total events   : #{total}"
    puts "  Confirmed      : #{confirmed}"
    puts "  Upcoming       : #{upcoming}"
    puts "  syncToken      : #{token}"
    last = CalendarEvent.order(synced_at: :desc).first
    puts "  Last synced    : #{last&.synced_at || 'never'}"
    puts ""
  end
end
