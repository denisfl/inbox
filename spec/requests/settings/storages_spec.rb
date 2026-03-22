require "rails_helper"

RSpec.describe "Settings::Storages", type: :request do
  describe "GET /settings/storage" do
    it "returns success" do
      get settings_storage_path
      expect(response).to have_http_status(:ok)
    end

    it "displays the current provider" do
      StorageSetting.create!(provider: "s3", active: true)

      get settings_storage_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Storage Settings")
    end

    it "displays status badge for persisted settings" do
      StorageSetting.create!(provider: "local", active: true, status: "ok", last_checked_at: 1.hour.ago)

      get settings_storage_path

      expect(response.body).to include("Ok")
    end
  end

  describe "PATCH /settings/storage" do
    it "creates a new storage setting" do
      expect {
        patch settings_storage_path, params: {
          storage_setting: { provider: "local" }
        }
      }.to change(StorageSetting, :count).by(1)

      expect(response).to redirect_to(settings_storage_path)
      follow_redirect!
      expect(response.body).to include("Storage settings saved")
    end

    it "updates an existing storage setting" do
      setting = StorageSetting.create!(provider: "local", active: true)

      patch settings_storage_path, params: {
        storage_setting: { provider: "s3" },
        config: { bucket: "my-bucket", region: "eu-west-1" }
      }

      expect(response).to redirect_to(settings_storage_path)
      setting.reload
      expect(setting.provider).to eq("s3")
      expect(setting.config_data["bucket"]).to eq("my-bucket")
      expect(setting.config_data["region"]).to eq("eu-west-1")
    end

    it "rejects invalid provider" do
      patch settings_storage_path, params: {
        storage_setting: { provider: "ftp" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /settings/storage/test_connection" do
    it "tests connection for local storage" do
      StorageSetting.create!(provider: "local", active: true)

      post test_connection_settings_storage_path

      expect(response).to redirect_to(settings_storage_path)
      follow_redirect!
      expect(response.body).to include("Connection successful")
    end

    it "redirects with alert when no settings exist" do
      post test_connection_settings_storage_path

      expect(response).to redirect_to(settings_storage_path)
      follow_redirect!
      expect(response.body).to include("No storage configured")
    end

    it "updates status to ok on success" do
      setting = StorageSetting.create!(provider: "local", active: true, status: "unchecked")

      post test_connection_settings_storage_path

      setting.reload
      expect(setting.status).to eq("ok")
      expect(setting.last_checked_at).to be_present
    end
  end
end
