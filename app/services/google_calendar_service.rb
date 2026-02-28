# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"

# GoogleCalendarService — syncs one or more Google Calendars into CalendarEvent records.
#
# Credentials come from ENV vars (preferred for Docker / RPi):
#   GOOGLE_CLIENT_ID        — OAuth2 client ID
#   GOOGLE_CLIENT_SECRET    — OAuth2 client secret
#   GOOGLE_REFRESH_TOKEN    — long-lived refresh token (obtained via rake google_calendar:authorize)
#   GOOGLE_CALENDAR_IDS     — comma-separated list of calendar IDs, e.g. "primary,work@group.calendar.google.com"
#                             Defaults to "primary" if not set.
#
# Each calendar's syncToken is stored in tmp/google_sync_token_<safe_id>.txt so that
# delta syncs work independently per calendar.
#
# Usage:
#   svc = GoogleCalendarService.new
#   svc.sync!   # syncs all calendars listed in GOOGLE_CALENDAR_IDS
#
class GoogleCalendarService
  CAL = Google::Apis::CalendarV3

  # ── Public API ──────────────────────────────────────────────────────────────

  def initialize
    @client_id = ENV.fetch("GOOGLE_CLIENT_ID") { raise "GOOGLE_CLIENT_ID env var is required" }
    @secret    = ENV.fetch("GOOGLE_CLIENT_SECRET") { raise "GOOGLE_CLIENT_SECRET env var is required" }
    @refresh   = ENV.fetch("GOOGLE_REFRESH_TOKEN") { raise "GOOGLE_REFRESH_TOKEN env var is required" }
    @calendar_ids = ENV.fetch("GOOGLE_CALENDAR_IDS", "primary").split(",").map(&:strip).reject(&:blank?)
    @calendar_ids = [ "primary" ] if @calendar_ids.empty?
  end

  # Full or incremental sync for every configured calendar.
  def sync!
    service = build_service

    @calendar_ids.each do |cal_id|
      Rails.logger.info "[GoogleCalendarService] Syncing calendar: #{cal_id}"
      sync_calendar!(service, cal_id)
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "[GoogleCalendarService] Auth error on #{cal_id}: #{e.message}"
      raise
    rescue Google::Apis::Error => e
      Rails.logger.error "[GoogleCalendarService] API error on #{cal_id}: #{e.message} (skipping)"
    rescue => e
      Rails.logger.error "[GoogleCalendarService] Unexpected error on #{cal_id}: #{e.class} — #{e.message} (skipping)"
    end
  end

  # List upcoming events (used by sidebar widget and agenda page).
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

  def sync_calendar!(service, cal_id)
    sync_token = load_sync_token(cal_id)

    if sync_token.present?
      delta_sync!(service, cal_id, sync_token)
    else
      full_sync!(service, cal_id)
    end
  end

  def full_sync!(service, cal_id)
    Rails.logger.info "[GoogleCalendarService] FULL sync: #{cal_id}"
    page_token = nil
    next_sync  = nil

    loop do
      result = service.list_events(
        cal_id,
        single_events: true,
        order_by:      "startTime",
        time_min:      3.months.ago.iso8601,
        time_max:      1.year.from_now.iso8601,
        page_token:    page_token,
        max_results:   250
      )

      process_items(result.items || [], cal_id)

      next_sync  = result.next_sync_token
      page_token = result.next_page_token
      break if page_token.nil?
    end

    save_sync_token(cal_id, next_sync)
    Rails.logger.info "[GoogleCalendarService] Full sync complete: #{cal_id}"
  end

  def delta_sync!(service, cal_id, sync_token)
    Rails.logger.info "[GoogleCalendarService] DELTA sync: #{cal_id}"
    page_token = nil
    next_sync  = nil

    loop do
      result = service.list_events(
        cal_id,
        sync_token: sync_token,
        page_token: page_token
      )

      process_items(result.items || [], cal_id)

      next_sync  = result.next_sync_token
      page_token = result.next_page_token
      break if page_token.nil?
    end

    save_sync_token(cal_id, next_sync)
    Rails.logger.info "[GoogleCalendarService] Delta sync complete: #{cal_id}"
  rescue Google::Apis::ClientError => e
    if e.status_code == 410
      # syncToken expired — fall back to full sync
      Rails.logger.warn "[GoogleCalendarService] syncToken expired for #{cal_id}, running full sync"
      clear_sync_token(cal_id)
      full_sync!(service, cal_id)
    else
      raise
    end
  end

  def process_items(items, cal_id)
    now = Time.current

    items.each do |item|
      if item.status == "cancelled"
        CalendarEvent.where(google_event_id: item.id).update_all(status: "cancelled")
        next
      end

      starts_at, ends_at, all_day = parse_time(item.start, item.end)
      next unless starts_at

      CalendarEvent.find_or_initialize_by(google_event_id: item.id).tap do |ev|
        ev.google_calendar_id = cal_id
        ev.source             = "google"
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
    return [ nil, nil, false ] if gstart.nil?

    if gstart.date.present?
      # All-day event: gstart.date is a Date object from the Google gem
      starts = Date.parse(gstart.date.to_s).beginning_of_day
      ends   = gend&.date.present? ? Date.parse(gend.date.to_s).beginning_of_day : nil
      [ starts, ends, true ]
    else
      starts = Time.parse(gstart.date_time.to_s)
      ends   = gend&.date_time.present? ? Time.parse(gend.date_time.to_s) : nil
      [ starts, ends, false ]
    end
  rescue ArgumentError => e
    Rails.logger.warn "[GoogleCalendarService] Could not parse time: #{e.message}"
    [ nil, nil, false ]
  end

  # syncToken is stored per calendar in tmp/google_sync_token_<safe_id>.txt
  def token_path(cal_id)
    safe = cal_id.gsub(/[^a-zA-Z0-9_\-]/, "_")
    Rails.root.join("tmp", "google_sync_token_#{safe}.txt")
  end

  def save_sync_token(cal_id, token)
    return if token.blank?
    File.write(token_path(cal_id), token)
    Rails.logger.debug "[GoogleCalendarService] syncToken saved for #{cal_id}"
  end

  def load_sync_token(cal_id)
    path = token_path(cal_id)
    File.read(path).strip if File.exist?(path)
  end

  def clear_sync_token(cal_id)
    path = token_path(cal_id)
    File.delete(path) if File.exist?(path)
  end
end
