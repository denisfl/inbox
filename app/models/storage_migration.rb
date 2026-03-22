class StorageMigration < ApplicationRecord
  VALID_STATUSES = %w[pending running completed failed cancelled].freeze

  validates :from_provider, :to_provider, presence: true
  validates :status, inclusion: { in: VALID_STATUSES }

  scope :active, -> { where(status: %w[pending running]) }

  def running?
    status == "running"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def cancelled?
    status == "cancelled"
  end

  def progress_percent
    return 0 if total_items.zero?
    ((completed_items.to_f / total_items) * 100).round
  end

  def append_error(message)
    current = error_log || ""
    self.error_log = current + "[#{Time.current.iso8601}] #{message}\n"
  end
end
