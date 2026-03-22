require "rails_helper"

RSpec.describe StorageAdapter::Dropbox do
  let(:config) { { "access_token" => "test-dropbox-token" } }
  let(:adapter) { described_class.new(config: config) }

  describe "#upload" do
    it "uploads a file to Dropbox with namespace prefix" do
      stub_request(:post, "https://api.dropboxapi.com/2/files/create_folder_v2")
        .to_return(status: 409, body: { error_summary: "path/conflict/folder" }.to_json)

      stub_request(:post, "https://content.dropboxapi.com/2/files/upload")
        .to_return(status: 200, body: { name: "backup.sql.gz" }.to_json)

      file = Tempfile.new("test")
      file.write("data")
      file.close

      result = adapter.upload(file.path, "backup.sql.gz", namespace: :backups)
      expect(result).to eq("/Apps/Inbox/backups/backup.sql.gz")

      file.unlink
    end
  end

  describe "#download" do
    it "downloads a file from Dropbox" do
      stub_request(:post, "https://content.dropboxapi.com/2/files/download")
        .to_return(status: 200, body: "file content")

      tempfile = adapter.download("test.txt", namespace: :files)
      expect(tempfile).to be_a(Tempfile)
      expect(tempfile.read).to eq("file content")

      tempfile.close!
    end
  end

  describe "#delete" do
    it "deletes a file from Dropbox" do
      stub_request(:post, "https://api.dropboxapi.com/2/files/delete_v2")
        .to_return(status: 200, body: { metadata: { name: "test.txt" } }.to_json)

      expect { adapter.delete("test.txt", namespace: :files) }.not_to raise_error
    end
  end

  describe "#list" do
    it "lists files in a namespace folder" do
      stub_request(:post, "https://api.dropboxapi.com/2/files/list_folder")
        .to_return(status: 200, body: {
          entries: [
            { ".tag" => "file", "name" => "a.txt" },
            { ".tag" => "file", "name" => "b.txt" },
            { ".tag" => "folder", "name" => "subfolder" }
          ],
          has_more: false
        }.to_json)

      result = adapter.list(namespace: :backups)
      expect(result).to eq(%w[a.txt b.txt])
    end

    it "handles pagination" do
      stub_request(:post, "https://api.dropboxapi.com/2/files/list_folder")
        .to_return(status: 200, body: {
          entries: [{ ".tag" => "file", "name" => "a.txt" }],
          has_more: true,
          cursor: "cursor123"
        }.to_json)

      stub_request(:post, "https://api.dropboxapi.com/2/files/list_folder/continue")
        .to_return(status: 200, body: {
          entries: [{ ".tag" => "file", "name" => "b.txt" }],
          has_more: false
        }.to_json)

      result = adapter.list(namespace: :files)
      expect(result).to eq(%w[a.txt b.txt])
    end

    it "returns empty array when folder not found" do
      stub_request(:post, "https://api.dropboxapi.com/2/files/list_folder")
        .to_return(status: 409, body: { error_summary: "path/not_found" }.to_json)

      result = adapter.list(namespace: :files)
      expect(result).to eq([])
    end
  end

  describe "#url" do
    it "returns a temporary link" do
      stub_request(:post, "https://api.dropboxapi.com/2/files/get_temporary_link")
        .to_return(status: 200, body: { link: "https://dl.dropbox.com/temp/test.txt" }.to_json)

      result = adapter.url("test.txt", namespace: :files)
      expect(result).to eq("https://dl.dropbox.com/temp/test.txt")
    end
  end

  describe "#test_connection" do
    it "returns ok when upload/download/delete succeeds" do
      stub_request(:post, "https://content.dropboxapi.com/2/files/upload")
        .to_return(status: 200, body: { name: ".storage_test" }.to_json)

      stub_request(:post, "https://content.dropboxapi.com/2/files/download")
        .to_return(status: 200, body: "ok")

      stub_request(:post, "https://api.dropboxapi.com/2/files/delete_v2")
        .to_return(status: 200, body: { metadata: {} }.to_json)

      result = adapter.test_connection
      expect(result[:ok]).to be true
    end

    it "returns error when connection fails" do
      stub_request(:post, "https://content.dropboxapi.com/2/files/upload")
        .to_return(status: 401, body: { error_summary: "invalid_access_token" }.to_json)

      result = adapter.test_connection
      expect(result[:ok]).to be false
      expect(result[:error]).to include("invalid_access_token")
    end
  end
end
