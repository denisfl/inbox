class BackupService
  RETENTION_DAYS_DEFAULT = 30

  def initialize(storage: BackupStorage.resolve)
    @storage = storage
  end

  def perform
    record = BackupRecord.create!(
      status: "running",
      started_at: Time.current,
      storage_type: ENV.fetch("BACKUP_STORAGE_TYPE", "local")
    )

    temp_path = dump_and_compress
    key = "backup_#{Time.current.strftime('%Y%m%d_%H%M%S')}.sql.gz"

    storage_path = @storage.upload(temp_path.to_s, key)

    record.update!(
      status: "completed",
      completed_at: Time.current,
      size_bytes: temp_path.size,
      storage_path: storage_path
    )

    cleanup_temp(temp_path)
    cleanup_retention

    record
  rescue => e
    record&.update!(
      status: "failed",
      completed_at: Time.current,
      error_message: "#{e.class}: #{e.message}"
    )
    Rails.logger.error("Backup failed: #{e.class}: #{e.message}")
    raise
  end

  def cleanup_retention
    retention_days = ENV.fetch("BACKUP_RETENTION_DAYS", RETENTION_DAYS_DEFAULT).to_i
    old_records = BackupRecord.older_than(retention_days).successful

    old_records.find_each do |record|
      if record.storage_path.present?
        key = File.basename(record.storage_path)
        @storage.delete(key)
      end
    rescue => e
      Rails.logger.warn("Failed to delete backup file for record #{record.id}: #{e.message}")
    end

    old_records.delete_all
  end

  private

  def dump_and_compress
    db_path = ActiveRecord::Base.connection_db_config.database
    temp_dir = Rails.root.join("tmp", "backups")
    FileUtils.mkdir_p(temp_dir)
    temp_path = temp_dir.join("backup_#{Time.current.strftime('%Y%m%d_%H%M%S')}.sql.gz")

    result = system("sqlite3 #{Shellwords.escape(db_path)} .dump | gzip > #{Shellwords.escape(temp_path.to_s)}")

    unless result && temp_path.exist? && temp_path.size > 0
      raise "SQLite dump failed: output file is missing or empty"
    end

    temp_path
  end

  def cleanup_temp(temp_path)
    FileUtils.rm_f(temp_path)
  end
end
