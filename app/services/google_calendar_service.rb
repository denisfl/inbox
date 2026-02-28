# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"

# GoogleCalendarService — thin wrapper around the Google Calendar API v3.
#
# Credentials are read from Rails credentials:
#   google_calendar:
#     client_id:      ...
#     client_secret:  ...
#     refresh_token:  ...
#     calendar_id:    "primary"
#     sync_token:     ...   (updated after every successful delta sync)
#
# Usage:
#   svc = GoogleCalendarService.new
#   svc.sync!   # full load on first run, delta on subsequent runs
#
class GoogleCalendarService
  CAL = Google::Apis::CalendarV3

  # ── Public API ──────────────────────────────────────────────────────────────

  def initialize
    @creds     = Rails.application.credentials.google_calendar || {}
    @client_id = @creds[:client_id]     or raise "google_calendar.client_id missing from credentials"
    @secret    = @creds[:client_secret] or raise "google_calendar.client_secret missing from credentials"
    @refresh   = @creds[:refresh_token] or raise "google_calendar.refresh_token missing from credentials"
    @calendar_id = @creds[:calendar_id].presence || "primary"
  end

  # Full or incremental sync.
  # On first call (no syncToken stored) performs a full load of future events.
  # On subsequent calls uses the stored syncToken for delta.
  def sync!
    service    = build_service
    sync_token = load_sync_token

    if sync_token.present?
      delta_sync!(service, sync_token)
    else
      full_sync!(service)
    end
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "[GoogleCalendarService] Auth error: #{e.message}"
    raise
  rescue Google::Apis::Error => e
    Rails.logger.error "[GoogleCalendarService] API error: #{e.message}"
    raise
  end

  # List upcoming events (used by sidebar widget and agenda page).
  # Returns an ActiveRecord relation.
  def self.upcoming_events(limit: 10)
    CalendarEvent.upcoming.limit(limit)
  end

  # ── Private ─────────────────────────────────────────────────────────────────
  private

  def build_service
    authorizer = Google::Auth::UserRefreshCredentials.new(
      client_id:     @client_id,
      client_secret: @secret,
      refresh_token: @refresh,
      scope:         "https://www.googleapis.com/auth/calendar.readonly"
    )
    svc = CAL::CalendarService.new
    svc.authorization = authorizer
    svc
  end

  def full_sync!(service)
    Rails.logger.info "[GoogleCalendarService] Starting FULL sync"
    page_token  = nil
    next_sync   = nil

    loop do
      result = service.list_events(
        @calendar_id,
        single_events: true,
        order_by:      "startTime",
        time_min:      1.month.ago.iso8601,
        time_max:      3.months.from_now.iso8601,
        page_token:    page_token,
        max_results:   250
      )

      process_items(result.items || [])

      next_sync  = result.next_sync_token
      page_token = result.next_page_token
      break if page_token.nil?
    end

    save_sync_token(next_sync)
    Rails.logger.info "[GoogleCalendarService] Full sync complete. Token saved."
  end

  def delta_sync!(service, sync_token)
    Rails.logger.info "[GoogleCalendarService] Starting DELTA sync"
    page_token  = nil
    next_sync   = nil

    loop do
      result = service.list_events(
        @calendar_id,
        sync_token: sync_token,
        page_token: page_token
      )

      process_items(result.items || [])

      next_sync  = result.next_sync_token
      page_token = result.next_page_token
      break if page_token.nil?
    end

    save_sync_token(next_sync)
    Rails.logger.info "[GoogleCalendarService] Delta sync complete."
  rescue Google::Apis::ClientError => e
    # 410 Gone = syncToken expired → fall back to full sync
    if e.status_code == 410
      Rails.logger.warn "[GoogleCalendarService] syncToken expired, running full sync"
      clear_sync_token
      full_sync!(service)
    else
      raise
    end
  end

  def process_items(items)
    now = Time.current

    items.each do |item|
      if item.status == "cancelled"
        CalendarEvent.where(google_event_id: item.id).update_all(status: "cancelled")
        next
      end

      starts_at, ends_at, all_day = parse_time(item.start, item.end)
      next unless starts_at # skip events we can't parse

      CalendarEvent.find_or_initialize_by(google_event_id: item.id).tap do |ev|
        ev.google_calendar_id = @calendar_id
        ev.title              = item.summary.presence || "(no title)"
        ev.description        = item.description
        ev.starts_at          = starts_at
        ev.ends_at            = ends_at
        ev.all_day            = all_day
        ev.color              = item.color_id
        ev.html_link          = item.html_link
        ev.status             = item.status || "confirmed"
        ev.synced_at          = now
        ev.save!
      end
    end
  end

  def parse_time(gstart, gend)
    return [nil, nil, false] if gstart.nil?

    if gstart.date.present?
      # All-day event
      starts = Date.parse(gstart.date).beginning_of_day
      ends   = gend&.date.present? ? Date.parse(gend.date).beginning_of_day : nil
      [starts, ends, true]
    else
      starts = Time.parse(gstart.date_time.to_s)
      ends   = gend&.date_time.present? ? Time.parse(gend.date_time.to_s) : nil
      [starts, ends, false]
    end
  rescue ArgumentError => e
    Rails.logger.warn "[GoogleCalendarService] Could not parse time: #{e.message}"
    [nil, nil, false]
  end

  def save_sync_token(token)
    return if token.blank?

    # Store in Rails credentials (encrypted). On production this requires
    # RAILS_MASTER_KEY. For a simpler approach in single-user setups, we
    # fall back to a plain JSON file in tmp/.
    token_path = Rails.root.join("tmp", "google_sync_token.txt")
    File.write(token_path, token)
    Rails.logger.debug "[GoogleCalendarService] syncToken saved to #{token_path}"
  end

  def load_sync_token
    token_path = Rails.root.join("tmp", "google_sync_token.txt")
    File.read(token_path).strip if File.exist?(token_path)
  end

  def clear_sync_token
    token_path = Rails.root.join("tmp", "google_sync_token.txt")
    File.delete(token_path) if File.exist?(token_path)
  end
end
