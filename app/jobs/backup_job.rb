# Daily automated SQLite database backup.
#
# Retry strategy:
#   - retry_on network errors (ECONNREFUSED, ETIMEDOUT, OpenTimeout): 3 attempts, 5 min wait
#   - discard_on ArgumentError: invalid configuration, no retry
class BackupJob < ApplicationJob
  queue_as :default

  retry_on Errno::ECONNREFUSED, Errno::ETIMEDOUT, Net::OpenTimeout, wait: 5.minutes, attempts: 3
  discard_on ArgumentError

  def perform
    BackupService.new.perform
  end
end
