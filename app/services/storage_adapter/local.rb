module StorageAdapter
  class Local < Base
    def initialize(base_path: ENV.fetch("STORAGE_LOCAL_PATH", Rails.root.join("storage").to_s))
      @base_path = Pathname.new(base_path)
    end

    def upload(file_path, key, namespace: :files)
      dir = namespace_path(namespace)
      FileUtils.mkdir_p(dir)
      destination = dir.join(key)
      FileUtils.cp(file_path, destination)
      destination.to_s
    end

    def download(key, namespace: :files)
      source = namespace_path(namespace).join(key)
      raise "File not found: #{source}" unless source.exist?

      tempfile = Tempfile.new([ "storage_download", File.extname(key) ])
      FileUtils.cp(source, tempfile.path)
      tempfile.rewind
      tempfile
    end

    def delete(key, namespace: :files)
      target = namespace_path(namespace).join(key)
      FileUtils.rm_f(target)
    end

    def list(namespace: :files)
      dir = namespace_path(namespace)
      return [] unless dir.directory?

      dir.children
        .select(&:file?)
        .map { |f| f.basename.to_s }
        .sort
    end

    def exist?(key, namespace: :files)
      namespace_path(namespace).join(key).exist?
    end

    def url(key, namespace: :files, expires_in: 1.hour)
      namespace_path(namespace).join(key).to_s
    end

    def test_connection
      dir = @base_path
      FileUtils.mkdir_p(dir)

      test_file = dir.join(".storage_test")
      File.write(test_file, "ok")
      FileUtils.rm_f(test_file)

      { ok: true }
    end

    private

    def namespace_path(namespace)
      @base_path.join(namespace.to_s)
    end
  end
end
