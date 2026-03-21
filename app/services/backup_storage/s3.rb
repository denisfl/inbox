module BackupStorage
  class S3 < Base
    def initialize(
      bucket: ENV.fetch("BACKUP_S3_BUCKET"),
      region: ENV.fetch("BACKUP_S3_REGION", "us-east-1"),
      access_key_id: AppSecret.fetch("BACKUP_S3_ACCESS_KEY"),
      secret_access_key: AppSecret.fetch("BACKUP_S3_SECRET_KEY"),
      endpoint: ENV["BACKUP_S3_ENDPOINT"]
    )
      @bucket = bucket
      @client_options = {
        region: region,
        credentials: Aws::Credentials.new(access_key_id, secret_access_key)
      }
      @client_options[:endpoint] = endpoint if endpoint.present?
    end

    def upload(file_path, key)
      object = s3_resource.bucket(@bucket).object("backups/#{key}")
      object.upload_file(file_path)
      "s3://#{@bucket}/backups/#{key}"
    end

    def delete(key)
      s3_resource.bucket(@bucket).object("backups/#{key}").delete
    end

    def list
      s3_resource.bucket(@bucket).objects(prefix: "backups/").map do |obj|
        obj.key.sub("backups/", "")
      end
    end

    private

    def s3_resource
      require "aws-sdk-s3"
      @s3_resource ||= Aws::S3::Resource.new(**@client_options)
    end
  end
end
