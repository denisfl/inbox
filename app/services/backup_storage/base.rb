module BackupStorage
  # DEPRECATED: Use StorageAdapter instead.
  # This module is kept for backward compatibility during transition.
  def self.resolve
    Rails.logger.warn("BackupStorage.resolve is deprecated. Use StorageAdapter.resolve instead.")
    adapter = StorageAdapter.resolve
    LegacyWrapper.new(adapter)
  end

  class LegacyWrapper
    def initialize(adapter)
      @adapter = adapter
    end

    def upload(file_path, key)
      @adapter.upload(file_path, key, namespace: :backups)
    end

    def delete(key)
      @adapter.delete(key, namespace: :backups)
    end

    def list
      @adapter.list(namespace: :backups)
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
