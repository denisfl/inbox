require "rails_helper"

RSpec.describe StorageAdapter::S3 do
  let(:config) do
    {
      "bucket" => "test-bucket",
      "region" => "us-west-2",
      "access_key_id" => "AKIAIOSFODNN7EXAMPLE",
      "secret_access_key" => "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    }
  end
  let(:adapter) { described_class.new(config: config) }

  let(:s3_resource) { instance_double(Aws::S3::Resource) }
  let(:bucket) { instance_double(Aws::S3::Bucket) }
  let(:object) { instance_double(Aws::S3::Object) }

  before do
    require "aws-sdk-s3"
    allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
    allow(s3_resource).to receive(:bucket).with("test-bucket").and_return(bucket)
  end

  describe "#upload" do
    it "uploads a file to the S3 bucket with namespace prefix" do
      allow(bucket).to receive(:object).with("backups/backup.sql.gz").and_return(object)
      allow(object).to receive(:upload_file).with("/path/to/file")

      result = adapter.upload("/path/to/file", "backup.sql.gz", namespace: :backups)

      expect(result).to eq("s3://test-bucket/backups/backup.sql.gz")
      expect(object).to have_received(:upload_file).with("/path/to/file")
    end

    it "uses default namespace :files" do
      allow(bucket).to receive(:object).with("files/photo.jpg").and_return(object)
      allow(object).to receive(:upload_file).with("/path/to/photo.jpg")

      adapter.upload("/path/to/photo.jpg", "photo.jpg")

      expect(bucket).to have_received(:object).with("files/photo.jpg")
    end
  end

  describe "#download" do
    it "downloads to a tempfile" do
      allow(bucket).to receive(:object).with("backups/backup.sql.gz").and_return(object)
      allow(object).to receive(:get) do |**opts|
        File.write(opts[:response_target], "backup data")
      end

      tempfile = adapter.download("backup.sql.gz", namespace: :backups)

      expect(tempfile).to be_a(Tempfile)
      expect(tempfile.read).to eq("backup data")
    ensure
      tempfile&.close!
    end
  end

  describe "#delete" do
    it "deletes an object from S3" do
      allow(bucket).to receive(:object).with("files/old.txt").and_return(object)
      allow(object).to receive(:delete)

      adapter.delete("old.txt", namespace: :files)

      expect(object).to have_received(:delete)
    end
  end

  describe "#list" do
    it "lists objects in a namespace prefix" do
      objects = [
        instance_double(Aws::S3::ObjectSummary, key: "backups/a.sql.gz"),
        instance_double(Aws::S3::ObjectSummary, key: "backups/b.sql.gz")
      ]
      allow(bucket).to receive(:objects).with(prefix: "backups/").and_return(objects)

      result = adapter.list(namespace: :backups)

      expect(result).to eq(["a.sql.gz", "b.sql.gz"])
    end
  end

  describe "#url" do
    it "returns a presigned URL" do
      allow(bucket).to receive(:object).with("files/photo.jpg").and_return(object)
      allow(object).to receive(:presigned_url).with(:get, expires_in: 3600).and_return("https://s3.example.com/signed")

      result = adapter.url("photo.jpg", namespace: :files, expires_in: 1.hour)

      expect(result).to eq("https://s3.example.com/signed")
    end
  end

  describe "#test_connection" do
    it "performs a round-trip test" do
      test_object = instance_double(Aws::S3::Object)
      allow(bucket).to receive(:object).and_return(test_object)
      allow(test_object).to receive(:put)
      allow(test_object).to receive(:get)
      allow(test_object).to receive(:delete)

      result = adapter.test_connection

      expect(result).to eq({ ok: true })
      expect(test_object).to have_received(:put)
      expect(test_object).to have_received(:get)
      expect(test_object).to have_received(:delete)
    end
  end

  describe ".from_legacy_env" do
    it "builds adapter from ENV variables" do
      allow(ENV).to receive(:fetch).with("BACKUP_S3_BUCKET").and_return("my-bucket")
      allow(ENV).to receive(:fetch).with("BACKUP_S3_REGION", "us-east-1").and_return("eu-west-1")
      allow(ENV).to receive(:[]).with("BACKUP_S3_ENDPOINT").and_return(nil)
      allow(AppSecret).to receive(:fetch).with("BACKUP_S3_ACCESS_KEY").and_return("key-id")
      allow(AppSecret).to receive(:fetch).with("BACKUP_S3_SECRET_KEY").and_return("secret")

      adapter = described_class.from_legacy_env

      expect(adapter).to be_a(described_class)
    end
  end
end
