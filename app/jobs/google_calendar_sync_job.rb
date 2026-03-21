# frozen_string_literal: true

# Syncs Google Calendar events into the local CalendarEvent table.
#
# First run: performs a full sync (1 month back → 3 months forward).
# Subsequent runs: uses stored syncToken for incremental delta sync.
#
# Retry strategy:
#   - retry_on StandardError: 3 attempts with exponential backoff
#   - Google API errors per-calendar are caught in GoogleCalendarService (non-auth errors skipped)
#   - Auth errors propagate up and trigger retry
#
# Schedule (config/recurring.yml):
#   google_calendar_sync:
#     class: GoogleCalendarSyncJob
#     queue: default
#     schedule: every 15 minutes
#
class GoogleCalendarSyncJob < ApplicationJob
  queue_as :default

  # Retry up to 3 times with exponential back-off.
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ArgumentError

  def perform
    Rails.logger.tagged("[google_calendar]") { Rails.logger.info "Starting sync" }
    GoogleCalendarService.new.sync!
    Rails.logger.tagged("[google_calendar]") { Rails.logger.info "Sync complete" }
  rescue => e
    Rails.logger.tagged("[google_calendar]") { Rails.logger.error "Failed: #{e.class} — #{e.message}" }
    raise
  end
end
