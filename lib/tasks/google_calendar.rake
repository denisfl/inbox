# frozen_string_literal: true

# rake google_calendar:authorize  — perform one-time OAuth2 flow to obtain refresh_token
# rake google_calendar:sync       — trigger a manual sync
# rake google_calendar:reset      — clear syncTokens (next sync will be full for all calendars)
# rake google_calendar:status     — show event counts

namespace :google_calendar do
  desc "One-time OAuth2 flow — starts local server, opens browser, saves refresh_token"
  task authorize: :environment do
    require "net/http"
    require "json"
    require "uri"
    require "socket"

    client_id     = ENV.fetch("GOOGLE_CLIENT_ID") { abort "GOOGLE_CLIENT_ID env var is required" }
    client_secret = ENV.fetch("GOOGLE_CLIENT_SECRET") { abort "GOOGLE_CLIENT_SECRET env var is required" }

    scope        = "https://www.googleapis.com/auth/calendar.readonly"
    port         = 8765
    callback_uri = "http://localhost:#{port}/oauth2callback"

    # Build auth URL (OOB flow is deprecated by Google — use localhost redirect instead)
    auth_params = URI.encode_www_form(
      client_id:     client_id,
      redirect_uri:  callback_uri,
      response_type: "code",
      scope:         scope,
      access_type:   "offline",
      prompt:        "consent"
    )
    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?#{auth_params}"

    puts ""
    puts "=" * 70
    puts "  GOOGLE CALENDAR AUTHORIZATION"
    puts "=" * 70
    puts ""
    puts "  Opening browser for OAuth2 consent..."
    puts "  URL: #{auth_url}"
    puts ""

    system("open '#{auth_url}' 2>/dev/null || xdg-open '#{auth_url}' 2>/dev/null || true")

    # Minimal TCP server — no WEBrick gem needed
    received_code = nil
    puts "  Waiting for browser redirect on http://localhost:#{port}/oauth2callback ..."
    puts "  (If browser did not open automatically, paste the URL above manually)"
    puts ""

    server = TCPServer.new("127.0.0.1", port)
    client = server.accept
    request = client.readpartial(4096)

    # Parse "GET /oauth2callback?code=XXX HTTP/1.1"
    if (m = request.match(/GET \/oauth2callback\?([^\s]+)/))
      params = URI.decode_www_form(m[1]).to_h
      received_code = params["code"]
    end

    resp_body = "<html><body><h2>Authorization received! You can close this tab.</h2></body></html>"
    client.write "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: #{resp_body.bytesize}\r\nConnection: close\r\n\r\n#{resp_body}"
    client.close
    server.close

    abort "No authorization code received." unless received_code

    # Exchange code for tokens
    token_uri = URI("https://oauth2.googleapis.com/token")
    response  = Net::HTTP.post_form(token_uri, {
      code:          received_code,
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
      puts "  GOOGLE_CALENDAR_IDS=delchyve@gmail.com"
      puts "  CALENDAR_REMINDER_MINUTES=10"
      puts ""
      puts "  Then run:  bin/rails google_calendar:sync"
      puts ""
    else
      puts "  ERROR: #{body.inspect}"
      abort "Failed to obtain refresh_token. Make sure http://localhost:#{port}/oauth2callback is listed as Authorized Redirect URI in Google Cloud Console."
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
