require "rails_helper"

RSpec.describe StorageHealthCheckJob, type: :job do
  describe "#perform" do
    it "does nothing when no storage setting exists" do
      expect { described_class.perform_now }.not_to raise_error
    end

    it "does nothing for local provider" do
      StorageSetting.create!(provider: "local", active: true)
      expect { described_class.perform_now }.not_to raise_error
    end

    it "updates status to ok when test_connection succeeds" do
      setting = StorageSetting.create!(provider: "dropbox", active: true, status: "unchecked")
      setting.update!(config_encrypted: { access_token: "test" }.to_json)

      adapter = instance_double(StorageAdapter::Dropbox)
      allow(adapter).to receive(:test_connection).and_return({ ok: true })
      allow(StorageAdapter).to receive(:resolve).and_return(adapter)

      described_class.perform_now

      setting.reload
      expect(setting.status).to eq("ok")
      expect(setting.last_checked_at).to be_present
    end

    it "updates status to error when test_connection fails" do
      setting = StorageSetting.create!(provider: "dropbox", active: true, status: "ok")
      setting.update!(config_encrypted: { access_token: "test" }.to_json)

      adapter = instance_double(StorageAdapter::Dropbox)
      allow(adapter).to receive(:test_connection).and_return({ ok: false, error: "connection refused" })
      allow(StorageAdapter).to receive(:resolve).and_return(adapter)

      described_class.perform_now

      setting.reload
      expect(setting.status).to eq("error")
      expect(setting.last_checked_at).to be_present
    end

    it "handles exceptions gracefully" do
      setting = StorageSetting.create!(provider: "dropbox", active: true, status: "ok")
      setting.update!(config_encrypted: { access_token: "test" }.to_json)

      allow(StorageAdapter).to receive(:resolve).and_raise(StandardError, "boom")

      expect { described_class.perform_now }.not_to raise_error

      setting.reload
      expect(setting.status).to eq("error")
    end
  end
end
