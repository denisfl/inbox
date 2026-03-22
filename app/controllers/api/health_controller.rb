class Api::HealthController < ActionController::API
  def show
    services = {
      database: check_database,
      transcriber: check_transcriber,
      google_calendar: check_google_calendar,
      storage: check_storage
    }
    backup = backup_status

    all_ok = services.values.all? { |s| %w[ok not_configured local].include?(s) } && backup[:status] != "failed"
    overall = if !services[:database].eql?("ok")
      "degraded"
    elsif all_ok
      "ok"
    else
      "degraded"
    end

    status_code = services[:database] == "ok" ? :ok : :service_unavailable
    # Override to 503 if backup failed
    status_code = :service_unavailable if backup[:status] == "failed"

    render json: {
      status: overall,
      services: services,
      backup: backup
    }, status: status_code
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    "ok"
  rescue => e
    Rails.logger.tagged("[health]") { Rails.logger.error("Database check failed: #{e.message}") }
    "unavailable"
  end

  def check_transcriber
    url = ENV["TRANSCRIBER_URL"]
    return "not_configured" if url.blank?

    client = ExternalServiceClient.new(:health_check)
    response = client.get("#{url}/health")
    response.status.success? ? "ok" : "unavailable"
  rescue => e
    Rails.logger.tagged("[health]") { Rails.logger.debug("Transcriber check failed: #{e.message}") }
    "unavailable"
  end

  def check_google_calendar
    client_id = ENV["GOOGLE_CLIENT_ID"].presence || AppSecret["GOOGLE_CLIENT_ID"]
    refresh_token = ENV["GOOGLE_REFRESH_TOKEN"].presence || AppSecret["GOOGLE_REFRESH_TOKEN"]

    if client_id.blank? || refresh_token.blank?
      return "not_configured"
    end

    "ok"
  rescue => e
    Rails.logger.tagged("[health]") { Rails.logger.debug("Google Calendar check failed: #{e.message}") }
    "unavailable"
  end

  def check_storage
    setting = StorageSetting.active_setting
    return "local" unless setting && setting.provider != "local"

    case setting.status
    when "ok" then "ok"
    when "error" then "error"
    else "unchecked"
    end
  rescue => e
    Rails.logger.tagged("[health]") { Rails.logger.debug("Storage check failed: #{e.message}") }
    "unavailable"
  end

  def backup_status
    record = BackupRecord.successful.order(started_at: :desc).first
    last_failed = BackupRecord.failed.order(started_at: :desc).first

    if record.nil? && last_failed.nil?
      { status: "never_run" }
    elsif last_failed && (record.nil? || last_failed.started_at > record.started_at)
      {
        status: "failed",
        last_success_at: record&.completed_at&.iso8601,
        last_error: last_failed.error_message
      }
    else
      {
        status: "ok",
        last_backup_at: record.completed_at.iso8601,
        size_bytes: record.size_bytes
      }
    end
  end
end
