module BackupStorage
  def self.resolve
    case ENV.fetch("BACKUP_STORAGE_TYPE", "local")
    when "s3"
      S3.new
    when "local"
      Local.new
    else
      raise ArgumentError, "Unknown BACKUP_STORAGE_TYPE: #{ENV['BACKUP_STORAGE_TYPE']}. Valid values: local, s3"
    end
  end

  class Base
    def upload(file_path, key)
      raise NotImplementedError, "#{self.class}#upload must be implemented"
    end

    def delete(key)
      raise NotImplementedError, "#{self.class}#delete must be implemented"
    end

    def list
      raise NotImplementedError, "#{self.class}#list must be implemented"
    end
  end
end
