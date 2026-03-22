class StorageSetting < ApplicationRecord
  VALID_PROVIDERS = %w[local s3 dropbox google_drive onedrive].freeze

  encrypts :config_encrypted

  validates :provider, presence: true, inclusion: { in: VALID_PROVIDERS }

  scope :active, -> { where(active: true) }

  def self.active_setting
    active.order(updated_at: :desc).first
  end

  def config_data
    return {} if config_encrypted.blank?
    JSON.parse(config_encrypted)
  rescue JSON::ParserError
    {}
  end

  def config_data=(hash)
    self.config_encrypted = hash.to_json
  end
end
