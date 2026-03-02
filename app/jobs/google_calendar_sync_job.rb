# frozen_string_literal: true

# Syncs Google Calendar events into the local CalendarEvent table.
#
# First run: performs a full sync (1 month back → 3 months forward).
# Subsequent runs: uses stored syncToken for incremental delta sync.
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

  def perform
    Rails.logger.info "[GoogleCalendarSyncJob] Starting sync"
    GoogleCalendarService.new.sync!
    Rails.logger.info "[GoogleCalendarSyncJob] Sync complete"
  rescue => e
    Rails.logger.error "[GoogleCalendarSyncJob] Failed: #{e.class} — #{e.message}"
    raise
  end
end
