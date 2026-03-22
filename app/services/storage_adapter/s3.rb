module StorageAdapter
  class S3 < Base
    def initialize(config: {})
      @bucket = config["bucket"] || config[:bucket]
      @region = config["region"] || config[:region] || "us-east-1"
      @access_key_id = config["access_key_id"] || config[:access_key_id]
      @secret_access_key = config["secret_access_key"] || config[:secret_access_key]
      @endpoint = config["endpoint"] || config[:endpoint]
    end

    def self.from_legacy_env
      new(config: {
        bucket: ENV.fetch("BACKUP_S3_BUCKET"),
        region: ENV.fetch("BACKUP_S3_REGION", "us-east-1"),
        access_key_id: AppSecret.fetch("BACKUP_S3_ACCESS_KEY"),
        secret_access_key: AppSecret.fetch("BACKUP_S3_SECRET_KEY"),
        endpoint: ENV["BACKUP_S3_ENDPOINT"]
      })
    end

    def upload(file_path, key, namespace: :files)
      prefix = namespace.to_s
      object = s3_resource.bucket(@bucket).object("#{prefix}/#{key}")
      object.upload_file(file_path)
      "s3://#{@bucket}/#{prefix}/#{key}"
    end

    def download(key, namespace: :files)
      prefix = namespace.to_s
      tempfile = Tempfile.new([ "s3_download", File.extname(key) ])
      s3_resource.bucket(@bucket).object("#{prefix}/#{key}").get(response_target: tempfile.path)
      tempfile.rewind
      tempfile
    end

    def delete(key, namespace: :files)
      prefix = namespace.to_s
      s3_resource.bucket(@bucket).object("#{prefix}/#{key}").delete
    end

    def list(namespace: :files)
      prefix = namespace.to_s
      s3_resource.bucket(@bucket).objects(prefix: "#{prefix}/").map do |obj|
        obj.key.sub("#{prefix}/", "")
      end
    end

    def url(key, namespace: :files, expires_in: 1.hour)
      prefix = namespace.to_s
      s3_resource.bucket(@bucket).object("#{prefix}/#{key}").presigned_url(:get, expires_in: expires_in.to_i)
    end

    def test_connection
      test_key = "files/.storage_test_#{SecureRandom.hex(4)}"
      obj = s3_resource.bucket(@bucket).object(test_key)
      obj.put(body: "ok")
      obj.get
      obj.delete
      { ok: true }
    end

    private

    def s3_resource
      require "aws-sdk-s3"
      @s3_resource ||= begin
        client_options = {
          region: @region,
          credentials: Aws::Credentials.new(@access_key_id, @secret_access_key)
        }
        client_options[:endpoint] = @endpoint if @endpoint.present?
        Aws::S3::Resource.new(**client_options)
      end
    end
  end
end
