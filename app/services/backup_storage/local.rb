module BackupStorage
  class Local < Base
    def initialize(path: ENV.fetch("BACKUP_LOCAL_PATH", Rails.root.join("storage", "backups").to_s))
      @path = Pathname.new(path)
    end

    def upload(file_path, key)
      FileUtils.mkdir_p(@path)
      destination = @path.join(key)
      FileUtils.cp(file_path, destination)
      destination.to_s
    end

    def delete(key)
      target = @path.join(key)
      FileUtils.rm_f(target)
    end

    def list
      return [] unless @path.directory?

      @path.children
        .select { |f| f.file? && f.extname == ".gz" }
        .map { |f| f.basename.to_s }
        .sort
    end
  end
end
