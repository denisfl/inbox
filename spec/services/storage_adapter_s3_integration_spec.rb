require "rails_helper"

# End-to-end integration test with a real S3-compatible backend (MinIO).
#
# This spec is skipped unless the MINIO_TEST_ENDPOINT ENV var is set.
# To run locally with MinIO in Docker:
#
#   docker run -d --name minio -p 9000:9000 -p 9001:9001 \
#     -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
#     minio/minio server /data --console-address ":9001"
#
#   # Create test bucket via mc CLI:
#   mc alias set local http://localhost:9000 minioadmin minioadmin
#   mc mb local/inbox-test
#
#   # Run the spec:
#   MINIO_TEST_ENDPOINT=http://localhost:9000 \
#   MINIO_TEST_ACCESS_KEY=minioadmin \
#   MINIO_TEST_SECRET_KEY=minioadmin \
#   MINIO_TEST_BUCKET=inbox-test \
#   bundle exec rspec spec/services/storage_adapter_s3_integration_spec.rb
#
RSpec.describe "StorageAdapter::S3 end-to-end with MinIO", type: :service do
  let(:endpoint)   { ENV["MINIO_TEST_ENDPOINT"] }
  let(:access_key) { ENV.fetch("MINIO_TEST_ACCESS_KEY", "minioadmin") }
  let(:secret_key) { ENV.fetch("MINIO_TEST_SECRET_KEY", "minioadmin") }
  let(:bucket)     { ENV.fetch("MINIO_TEST_BUCKET", "inbox-test") }

  before(:all) do
    skip "Set MINIO_TEST_ENDPOINT to run S3 integration tests" unless ENV["MINIO_TEST_ENDPOINT"]
  end

  before do
    skip "Set MINIO_TEST_ENDPOINT to run S3 integration tests" unless endpoint

    WebMock.allow_net_connect!

    @setting = StorageSetting.create!(
      provider: "s3",
      active: true,
      status: "unchecked"
    )
    @setting.config_data = {
      "access_key_id" => access_key,
      "secret_access_key" => secret_key,
      "region" => "us-east-1",
      "bucket" => bucket,
      "endpoint" => endpoint
    }
    @setting.save!
  end

  after do
    # Clean up test files from the bucket
    if endpoint
      adapter = StorageAdapter.resolve
      adapter.list(namespace: "integration-test").each do |name|
        adapter.delete(name, namespace: "integration-test")
      rescue => e
        Rails.logger.debug("Cleanup failed for #{name}: #{e.message}")
      end
      @setting&.destroy
      WebMock.disable_net_connect!(allow_localhost: true)
    end
  end

  it "uploads, downloads, lists, and deletes a file" do
    adapter = StorageAdapter.resolve
    test_content = "Hello from integration test #{SecureRandom.hex(8)}"

    # Create temp file
    file = Tempfile.new([ "integration", ".txt" ])
    file.write(test_content)
    file.rewind

    # Upload
    adapter.upload(file.path, "test-file.txt", namespace: "integration-test")

    # List
    files = adapter.list(namespace: "integration-test")
    expect(files).to include("test-file.txt")

    # Download
    downloaded = adapter.download("test-file.txt", namespace: "integration-test")
    expect(File.read(downloaded.path)).to eq(test_content)

    # URL
    url = adapter.url("test-file.txt", namespace: "integration-test")
    expect(url).to be_a(String)
    expect(url).to include("test-file.txt")

    # Delete
    adapter.delete("test-file.txt", namespace: "integration-test")

    # Verify deleted
    files_after = adapter.list(namespace: "integration-test")
    expect(files_after).not_to include("test-file.txt")
  ensure
    file&.close
    file&.unlink
    downloaded&.close
    downloaded&.unlink
  end

  it "test_connection succeeds" do
    adapter = StorageAdapter.resolve
    expect { adapter.test_connection }.not_to raise_error
  end
end
