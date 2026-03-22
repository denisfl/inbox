require "rails_helper"

RSpec.describe StorageMigrationJob, type: :job do
  let(:from_adapter) { instance_double(StorageAdapter::Local) }
  let(:to_adapter) { instance_double(StorageAdapter::Dropbox) }
  let(:tempfile) do
    t = Tempfile.new("test")
    t.write("content")
    t.rewind
    t
  end

  before do
    allow(StorageAdapter::Local).to receive(:new).and_return(from_adapter)
  end

  describe "#perform" do
    it "migrates blobs and backup records" do
      setting = StorageSetting.create!(provider: "dropbox", active: true)
      setting.update!(config_encrypted: { access_token: "test" }.to_json)

      migration = StorageMigration.create!(
        from_provider: "local",
        to_provider: "dropbox",
        status: "pending"
      )

      blob = ActiveStorage::Blob.create!(
        key: "test-blob-key",
        filename: "test.txt",
        content_type: "text/plain",
        byte_size: 100,
        checksum: "abc",
        service_name: "local"
      )

      backup = BackupRecord.create!(
        status: "completed",
        storage_path: "/backups/backup_20260101.sql.gz",
        storage_type: "local",
        started_at: 1.day.ago,
        completed_at: 1.day.ago
      )

      allow(from_adapter).to receive(:download).and_return(tempfile)
      allow(StorageAdapter::Dropbox).to receive(:new).and_return(to_adapter)
      allow(to_adapter).to receive(:upload).and_return("key")
      allow(OAuthManager).to receive(:new).and_return(instance_double(OAuthManager, ensure_fresh_token!: setting, oauth_provider?: true))

      described_class.perform_now(migration.id)

      migration.reload
      expect(migration.status).to eq("completed")
      expect(migration.completed_items).to eq(2)
      expect(migration.failed_items).to eq(0)
      expect(migration.total_items).to eq(2)
    end

    it "handles individual item failures gracefully" do
      setting = StorageSetting.create!(provider: "dropbox", active: true)
      setting.update!(config_encrypted: { access_token: "test" }.to_json)

      migration = StorageMigration.create!(
        from_provider: "local",
        to_provider: "dropbox",
        status: "pending"
      )

      ActiveStorage::Blob.create!(
        key: "fail-blob",
        filename: "fail.txt",
        content_type: "text/plain",
        byte_size: 100,
        checksum: "abc",
        service_name: "local"
      )

      allow(from_adapter).to receive(:download).and_raise(StandardError, "download failed")
      allow(StorageAdapter::Dropbox).to receive(:new).and_return(to_adapter)
      allow(OAuthManager).to receive(:new).and_return(instance_double(OAuthManager, ensure_fresh_token!: setting, oauth_provider?: true))

      described_class.perform_now(migration.id)

      migration.reload
      expect(migration.status).to eq("completed")
      expect(migration.failed_items).to eq(1)
      expect(migration.error_log).to include("download failed")
    end

    it "respects cancellation" do
      migration = StorageMigration.create!(
        from_provider: "local",
        to_provider: "dropbox",
        status: "cancelled"
      )

      described_class.perform_now(migration.id)

      migration.reload
      expect(migration.status).to eq("cancelled")
    end
  end
end
