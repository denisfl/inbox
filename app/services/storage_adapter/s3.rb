module StorageAdapter
  class S3 < Base
    def initialize(config: {})
      config = config.with_indifferent_access
      @bucket = config[:bucket]
      @region = config[:region] || "us-east-1"
      @access_key_id = config[:access_key_id]
      @secret_access_key = config[:secret_access_key]
      @endpoint = config[:endpoint]
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
      s3_object(key, namespace).upload_file(file_path)
      "s3://#{@bucket}/#{namespace}/#{key}"
    end

    def download(key, namespace: :files)
      tempfile = Tempfile.new([ "s3_download", File.extname(key) ])
      s3_object(key, namespace).get(response_target: tempfile.path)
      tempfile.rewind
      tempfile
    end

    def delete(key, namespace: :files)
      s3_object(key, namespace).delete
    end

    def list(namespace: :files)
      prefix = namespace.to_s
      bucket.objects(prefix: "#{prefix}/").map do |obj|
        obj.key.sub("#{prefix}/", "")
      end
    end

    def exist?(key, namespace: :files)
      s3_object(key, namespace).exists?
    end

    def url(key, namespace: :files, expires_in: 1.hour)
      s3_object(key, namespace).presigned_url(:get, expires_in: expires_in.to_i)
    end

    def test_connection
      test_key = ".storage_test_#{SecureRandom.hex(4)}"
      obj = s3_object(test_key, :files)
      obj.put(body: "ok")
      obj.get
      obj.delete
      { ok: true }
    end

    private

    def bucket
      s3_resource.bucket(@bucket)
    end

    def s3_object(key, namespace)
      bucket.object("#{namespace}/#{key}")
    end

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
