module StorageAdapter
  ADAPTER_CLASSES = {
    "s3" => "S3",
    "dropbox" => "Dropbox",
    "google_drive" => "GoogleDrive",
    "onedrive" => "OneDrive"
  }.freeze

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
      build(setting.provider, setting.config_data)
    end
  end

  def self.build(provider, config_data = {})
    klass_name = ADAPTER_CLASSES[provider]
    return Local.new unless klass_name

    const_get(klass_name).new(config: config_data)
  end

  class ApiError < StandardError; end

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

    def exist?(key, namespace: :files)
      list(namespace: namespace).include?(key)
    end

    def url(key, namespace: :files, expires_in: 1.hour)
      raise NotImplementedError, "#{self.class}#url must be implemented"
    end

    def test_connection
      raise NotImplementedError, "#{self.class}#test_connection must be implemented"
    end

    private

    def auth_client(timeout: 30)
      HTTP.timeout(timeout).auth("Bearer #{@access_token}")
    end
  end
end
