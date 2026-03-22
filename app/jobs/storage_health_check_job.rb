class StorageHealthCheckJob < ApplicationJob
  queue_as :default

  def perform
    setting = StorageSetting.active_setting
    return unless setting
    return if setting.provider == "local"

    adapter = StorageAdapter.resolve
    result = adapter.test_connection

    if result[:ok]
      setting.update!(status: "ok", last_checked_at: Time.current)
    else
      setting.update!(status: "error", last_checked_at: Time.current)
      Rails.logger.warn("[storage-health] Health check failed for #{setting.provider}: #{result[:error]}")
    end
  rescue => e
    setting&.update(status: "error", last_checked_at: Time.current)
    Rails.logger.warn("[storage-health] Health check error: #{e.class}: #{e.message}")
  end
end
