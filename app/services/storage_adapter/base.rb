module StorageAdapter
  def self.resolve
    setting = StorageSetting.active_setting rescue nil

    if setting.nil? || setting.provider == "local"
      # Check legacy ENV for backward compatibility
      if ENV["BACKUP_STORAGE_TYPE"] == "s3" && !setting
        S3.from_legacy_env
      else
        Local.new
      end
    else
      # Refresh OAuth tokens if expired
      oauth = OAuthManager.new
      setting = oauth.ensure_fresh_token!(setting) if oauth.oauth_provider?(setting.provider)

      case setting.provider
      when "s3"
        S3.new(config: setting.config_data)
      when "dropbox"
        Dropbox.new(config: setting.config_data)
      when "google_drive"
        GoogleDrive.new(config: setting.config_data)
      when "onedrive"
        OneDrive.new(config: setting.config_data)
      else
        Local.new
      end
    end
  end

  class Base
    def upload(file_path, key, namespace: :files)
      raise NotImplementedError, "#{self.class}#upload must be implemented"
    end

    def download(key, namespace: :files)
      raise NotImplementedError, "#{self.class}#download must be implemented"
    end

    def delete(key, namespace: :files)
      raise NotImplementedError, "#{self.class}#delete must be implemented"
    end

    def list(namespace: :files)
      raise NotImplementedError, "#{self.class}#list must be implemented"
    end

    def url(key, namespace: :files, expires_in: 1.hour)
      raise NotImplementedError, "#{self.class}#url must be implemented"
    end

    def test_connection
      raise NotImplementedError, "#{self.class}#test_connection must be implemented"
    end
  end
end
