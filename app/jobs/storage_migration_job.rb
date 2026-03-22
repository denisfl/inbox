class StorageMigrationJob < ApplicationJob
  queue_as :default

  def perform(migration_id)
    migration = StorageMigration.find(migration_id)
    return unless migration.status.in?(%w[pending running])

    migration.update!(status: "running", started_at: Time.current)

    from_adapter = build_adapter(migration.from_provider)
    to_adapter = build_adapter(migration.to_provider)

    # Count items
    blobs = ActiveStorage::Blob.all
    backup_records = BackupRecord.where.not(storage_path: [ nil, "" ]).where(status: "completed")
    migration.update!(total_items: blobs.count + backup_records.count)

    # Migrate ActiveStorage blobs
    blobs.find_each do |blob|
      break if migration.reload.cancelled?
      migrate_blob(blob, from_adapter, to_adapter, migration)
    end

    # Migrate backup files
    backup_records.find_each do |record|
      break if migration.reload.cancelled?
      migrate_backup(record, from_adapter, to_adapter, migration)
    end

    migration.reload
    if migration.cancelled?
      # Already marked cancelled
    elsif migration.failed_items.positive?
      migration.update!(status: "completed", completed_at: Time.current)
    else
      migration.update!(status: "completed", completed_at: Time.current)
    end
  rescue => e
    migration&.update(status: "failed", completed_at: Time.current)
    migration&.append_error("Job failed: #{e.class}: #{e.message}")
    migration&.save
    Rails.logger.error("StorageMigrationJob failed: #{e.class}: #{e.message}")
  end

  private

  def migrate_blob(blob, from_adapter, to_adapter, migration)
    tempfile = from_adapter.download(blob.key, namespace: :files)
    to_adapter.upload(tempfile.path, blob.key, namespace: :files)
    migration.increment!(:completed_items)
  rescue => e
    migration.increment!(:failed_items)
    migration.append_error("Blob #{blob.key}: #{e.class}: #{e.message}")
    migration.save
    Rails.logger.warn("Failed to migrate blob #{blob.key}: #{e.message}")
  ensure
    tempfile&.close!
  end

  def migrate_backup(record, from_adapter, to_adapter, migration)
    key = File.basename(record.storage_path)
    tempfile = from_adapter.download(key, namespace: :backups)
    to_adapter.upload(tempfile.path, key, namespace: :backups)
    migration.increment!(:completed_items)
  rescue => e
    migration.increment!(:failed_items)
    migration.append_error("Backup #{record.id}: #{e.class}: #{e.message}")
    migration.save
    Rails.logger.warn("Failed to migrate backup #{record.id}: #{e.message}")
  ensure
    tempfile&.close!
  end

  def build_adapter(provider)
    case provider
    when "local"
      StorageAdapter::Local.new
    else
      setting = StorageSetting.active_setting
      return StorageAdapter::Local.new unless setting

      oauth = OAuthManager.new
      setting = oauth.ensure_fresh_token!(setting) if oauth.oauth_provider?(setting.provider)

      case provider
      when "s3"
        StorageAdapter::S3.new(config: setting.config_data)
      when "dropbox"
        StorageAdapter::Dropbox.new(config: setting.config_data)
      when "google_drive"
        StorageAdapter::GoogleDrive.new(config: setting.config_data)
      when "onedrive"
        StorageAdapter::OneDrive.new(config: setting.config_data)
      else
        StorageAdapter::Local.new
      end
    end
  end
end
