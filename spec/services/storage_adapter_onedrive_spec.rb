require "rails_helper"

RSpec.describe StorageAdapter::OneDrive do
  let(:config) { { "access_token" => "test-onedrive-token" } }
  let(:adapter) { described_class.new(config: config) }

  let(:graph_url) { "https://graph.microsoft.com/v1.0" }

  describe "#upload" do
    it "uploads a file to OneDrive" do
      stub_request(:put, "#{graph_url}/me/drive/root:/Apps/Inbox/backups/backup.sql.gz:/content")
        .to_return(status: 201, body: { id: "file_id", name: "backup.sql.gz" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      file = Tempfile.new("test")
      file.write("data")
      file.close

      result = adapter.upload(file.path, "backup.sql.gz", namespace: :backups)
      expect(result).to eq("backup.sql.gz")

      file.unlink
    end
  end

  describe "#download" do
    it "downloads a file via redirect" do
      stub_request(:get, "#{graph_url}/me/drive/root:/Apps/Inbox/files/test.txt:/content")
        .to_return(status: 302, headers: { "Location" => "https://download.example.com/file" })

      stub_request(:get, "https://download.example.com/file")
        .to_return(status: 200, body: "file content")

      tempfile = adapter.download("test.txt", namespace: :files)
      expect(tempfile).to be_a(Tempfile)
      expect(tempfile.read).to eq("file content")

      tempfile.close!
    end

    it "downloads a file with direct response" do
      stub_request(:get, "#{graph_url}/me/drive/root:/Apps/Inbox/files/test.txt:/content")
        .to_return(status: 200, body: "file content")

      tempfile = adapter.download("test.txt", namespace: :files)
      expect(tempfile.read).to eq("file content")

      tempfile.close!
    end
  end

  describe "#delete" do
    it "deletes a file from OneDrive" do
      stub_request(:delete, "#{graph_url}/me/drive/root:/Apps/Inbox/files/test.txt:")
        .to_return(status: 204)

      expect { adapter.delete("test.txt", namespace: :files) }.not_to raise_error
    end

    it "handles already-deleted files gracefully" do
      stub_request(:delete, "#{graph_url}/me/drive/root:/Apps/Inbox/files/missing.txt:")
        .to_return(status: 404, body: { error: { code: "itemNotFound", message: "Item not found" } }.to_json)

      expect { adapter.delete("missing.txt", namespace: :files) }.not_to raise_error
    end
  end

  describe "#list" do
    it "lists files in a namespace folder" do
      stub_request(:get, /#{Regexp.escape(graph_url)}\/me\/drive\/root:\/Apps\/Inbox\/backups:\/children/)
        .to_return(status: 200, body: {
          value: [
            { name: "a.sql.gz", file: {} },
            { name: "b.sql.gz", file: {} },
            { name: "subfolder", folder: { childCount: 0 } }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.list(namespace: :backups)
      expect(result).to eq(%w[a.sql.gz b.sql.gz])
    end

    it "handles pagination" do
      stub_request(:get, /#{Regexp.escape(graph_url)}\/me\/drive\/root:\/Apps\/Inbox\/files:\/children/)
        .to_return(status: 200, body: {
          value: [ { name: "a.txt", file: {} } ],
          "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/drive/items/123/children?$skiptoken=abc"
        }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:get, "https://graph.microsoft.com/v1.0/me/drive/items/123/children?$skiptoken=abc")
        .to_return(status: 200, body: {
          value: [ { name: "b.txt", file: {} } ]
        }.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.list(namespace: :files)
      expect(result).to eq(%w[a.txt b.txt])
    end

    it "returns empty array when folder not found" do
      stub_request(:get, /#{Regexp.escape(graph_url)}\/me\/drive\/root:\/Apps\/Inbox\/files:\/children/)
        .to_return(status: 404, body: { error: { code: "itemNotFound", message: "The resource could not be found." } }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = adapter.list(namespace: :files)
      expect(result).to eq([])
    end
  end

  describe "#url" do
    it "returns a sharing link" do
      stub_request(:post, "#{graph_url}/me/drive/root:/Apps/Inbox/files/test.txt:/createLink")
        .to_return(status: 200, body: {
          link: { webUrl: "https://onedrive.live.com/share/test.txt" }
        }.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.url("test.txt", namespace: :files)
      expect(result).to eq("https://onedrive.live.com/share/test.txt")
    end
  end

  describe "#test_connection" do
    it "returns ok when upload/download/delete succeeds" do
      stub_request(:put, /#{Regexp.escape(graph_url)}\/me\/drive\/root:\/Apps\/Inbox\/files\/.storage_test.*:\/content/)
        .to_return(status: 201, body: { id: "test_id", name: ".storage_test" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      stub_request(:get, /#{Regexp.escape(graph_url)}\/me\/drive\/root:\/Apps\/Inbox\/files\/.storage_test.*:\/content/)
        .to_return(status: 200, body: "ok")

      stub_request(:delete, /#{Regexp.escape(graph_url)}\/me\/drive\/root:\/Apps\/Inbox\/files\/.storage_test.*:/)
        .to_return(status: 204)

      result = adapter.test_connection
      expect(result[:ok]).to be true
    end

    it "returns error when connection fails" do
      stub_request(:put, /#{Regexp.escape(graph_url)}\/me\/drive\/root:\/Apps\/Inbox\/files\/.storage_test.*:\/content/)
        .to_return(status: 401, body: { error: { code: "InvalidAuthenticationToken", message: "Access token is empty." } }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = adapter.test_connection
      expect(result[:ok]).to be false
      expect(result[:error]).to include("Access token is empty")
    end
  end
end
