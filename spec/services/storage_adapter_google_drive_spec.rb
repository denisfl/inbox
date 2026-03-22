require "rails_helper"

RSpec.describe StorageAdapter::GoogleDrive do
  let(:config) do
    {
      "access_token" => "test-gdrive-token",
      "folder_ids" => { "files" => "folder_files_id", "backups" => "folder_backups_id" }
    }
  end
  let(:adapter) { described_class.new(config: config) }

  let(:api_url) { "https://www.googleapis.com/drive/v3" }
  let(:upload_url) { "https://www.googleapis.com/upload/drive/v3" }

  describe "#upload" do
    it "creates a new file in the namespace folder" do
      # File not found (no existing)
      stub_request(:get, /#{api_url}\/files\?.*q=.*folder_files_id.*/)
        .to_return(status: 200, body: { files: [] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      # Multipart upload
      stub_request(:post, "#{upload_url}/files?uploadType=multipart")
        .to_return(status: 200, body: { id: "new_file_id", name: "test.txt" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      file = Tempfile.new("test")
      file.write("data")
      file.close

      result = adapter.upload(file.path, "test.txt", namespace: :files)
      expect(result).to eq("test.txt")

      file.unlink
    end

    it "updates an existing file" do
      # File found
      stub_request(:get, /#{api_url}\/files\?.*q=.*folder_files_id.*/)
        .to_return(status: 200, body: { files: [ { id: "existing_id", name: "test.txt" } ] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      # Media update
      stub_request(:patch, "#{upload_url}/files/existing_id?uploadType=media")
        .to_return(status: 200, body: { id: "existing_id", name: "test.txt" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      file = Tempfile.new("test")
      file.write("updated data")
      file.close

      result = adapter.upload(file.path, "test.txt", namespace: :files)
      expect(result).to eq("test.txt")

      file.unlink
    end
  end

  describe "#download" do
    it "downloads a file from Google Drive" do
      # Find file
      stub_request(:get, /#{api_url}\/files\?.*q=.*folder_files_id.*/)
        .to_return(status: 200, body: { files: [ { id: "file_id", name: "test.txt" } ] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      # Download content
      stub_request(:get, "#{api_url}/files/file_id?alt=media")
        .to_return(status: 200, body: "file content")

      tempfile = adapter.download("test.txt", namespace: :files)
      expect(tempfile).to be_a(Tempfile)
      expect(tempfile.read).to eq("file content")

      tempfile.close!
    end

    it "raises error when file not found" do
      stub_request(:get, /#{api_url}\/files\?.*q=.*folder_files_id.*/)
        .to_return(status: 200, body: { files: [] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { adapter.download("missing.txt", namespace: :files) }
        .to raise_error(StorageAdapter::GoogleDrive::ApiError, /File not found/)
    end
  end

  describe "#delete" do
    it "deletes a file from Google Drive" do
      # Find file
      stub_request(:get, /#{api_url}\/files\?.*q=.*folder_files_id.*/)
        .to_return(status: 200, body: { files: [ { id: "file_id", name: "test.txt" } ] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      # Delete
      stub_request(:delete, "#{api_url}/files/file_id")
        .to_return(status: 204)

      expect { adapter.delete("test.txt", namespace: :files) }.not_to raise_error
    end

    it "does nothing when file not found" do
      stub_request(:get, /#{api_url}\/files\?.*q=.*folder_files_id.*/)
        .to_return(status: 200, body: { files: [] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { adapter.delete("missing.txt", namespace: :files) }.not_to raise_error
    end
  end

  describe "#list" do
    it "lists files in a namespace folder" do
      stub_request(:get, /#{api_url}\/files\?.*q=.*folder_backups_id.*/)
        .to_return(status: 200, body: {
          files: [
            { id: "f1", name: "a.txt" },
            { id: "f2", name: "b.txt" }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.list(namespace: :backups)
      expect(result).to eq(%w[a.txt b.txt])
    end

    it "handles pagination" do
      # First page
      stub_request(:get, /#{api_url}\/files\?.*q=.*folder_files_id.*/)
        .with { |req| !req.uri.query.include?("pageToken") }
        .to_return(status: 200, body: {
          files: [ { id: "f1", name: "a.txt" } ],
          nextPageToken: "token123"
        }.to_json, headers: { "Content-Type" => "application/json" })

      # Second page
      stub_request(:get, /#{api_url}\/files\?.*pageToken=token123.*/)
        .to_return(status: 200, body: {
          files: [ { id: "f2", name: "b.txt" } ]
        }.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.list(namespace: :files)
      expect(result).to eq(%w[a.txt b.txt])
    end

    it "returns empty array when folder_id not set" do
      adapter_no_folders = described_class.new(config: { "access_token" => "token" })
      result = adapter_no_folders.list(namespace: :files)
      expect(result).to eq([])
    end
  end

  describe "#url" do
    it "returns API media URL" do
      stub_request(:get, /#{api_url}\/files\?.*q=.*folder_files_id.*/)
        .to_return(status: 200, body: { files: [ { id: "file_id", name: "test.txt" } ] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = adapter.url("test.txt", namespace: :files)
      expect(result).to eq("#{api_url}/files/file_id?alt=media")
    end
  end

  describe "#test_connection" do
    it "returns ok when upload/download/delete succeeds" do
      # Catch-all for folder/file lookups via Drive API — returns appropriate responses
      # The test_connection flow: ensure_namespace_folder! → find_file → create_file → find_file → download → delete
      call_count = 0
      stub_request(:get, /#{Regexp.escape(api_url)}\/files\?/)
        .to_return do |request|
          call_count += 1
          case call_count
          when 1 # ensure_folder! "Inbox" in "root"
            { status: 200, body: { files: [ { id: "inbox_id", name: "Inbox" } ] }.to_json,
              headers: { "Content-Type" => "application/json" } }
          when 2 # ensure_folder! "files" in "inbox_id"
            { status: 200, body: { files: [ { id: "files_folder_id", name: "files" } ] }.to_json,
              headers: { "Content-Type" => "application/json" } }
          when 3 # find_file after create_file (found)
            { status: 200, body: { files: [ { id: "test_file_id", name: ".storage_test" } ] }.to_json,
              headers: { "Content-Type" => "application/json" } }
          else
            { status: 200, body: { files: [] }.to_json,
              headers: { "Content-Type" => "application/json" } }
          end
        end

      stub_request(:post, "#{upload_url}/files?uploadType=multipart")
        .to_return(status: 200, body: { id: "test_file_id", name: ".storage_test" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      stub_request(:get, "#{api_url}/files/test_file_id?alt=media")
        .to_return(status: 200, body: "ok")

      stub_request(:delete, "#{api_url}/files/test_file_id")
        .to_return(status: 204)

      adapter_fresh = described_class.new(config: { "access_token" => "test-token" })
      result = adapter_fresh.test_connection
      expect(result[:ok]).to be true
    end

    it "returns error when connection fails" do
      stub_request(:get, /#{Regexp.escape(api_url)}\/files\?/)
        .to_return(status: 401, body: { error: { message: "Invalid credentials" } }.to_json,
                   headers: { "Content-Type" => "application/json" })

      adapter_fresh = described_class.new(config: { "access_token" => "bad-token" })
      result = adapter_fresh.test_connection
      expect(result[:ok]).to be false
      expect(result[:error]).to include("Invalid credentials")
    end
  end

  describe "#folder_ids" do
    it "returns a copy of cached folder IDs" do
      ids = adapter.folder_ids
      expect(ids).to eq({ "files" => "folder_files_id", "backups" => "folder_backups_id" })
      # Should be a copy, not the original
      ids["files"] = "modified"
      expect(adapter.folder_ids["files"]).to eq("folder_files_id")
    end
  end
end
