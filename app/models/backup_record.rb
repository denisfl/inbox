class BackupRecord < ApplicationRecord
  STATUSES = %w[running completed failed].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :storage_type, presence: true
  validates :started_at, presence: true

  scope :latest, -> { order(started_at: :desc).limit(1) }
  scope :successful, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :older_than, ->(days) { where("created_at < ?", days.days.ago) }
end
