require "rails_helper"

RSpec.describe "Settings::StorageOauth", type: :request do
  describe "GET /settings/storage/oauth/:provider/authorize" do
    it "redirects to the OAuth provider authorize URL" do
      allow(ENV).to receive(:fetch).with("DROPBOX_CLIENT_ID").and_return("db-client-id")

      get settings_storage_oauth_authorize_path(provider: "dropbox")

      expect(response).to have_http_status(:redirect)
      expect(response.location).to start_with("https://www.dropbox.com/oauth2/authorize")
    end

    it "stores state in the session" do
      allow(ENV).to receive(:fetch).with("GOOGLE_DRIVE_CLIENT_ID").and_return("gd-client-id")

      get settings_storage_oauth_authorize_path(provider: "google_drive")

      expect(session[:oauth_state]).to be_present
    end

    it "rejects unknown providers" do
      get settings_storage_oauth_authorize_path(provider: "ftp")

      expect(response).to redirect_to(settings_storage_path)
      follow_redirect!
      expect(response.body).to include("Unknown provider")
    end

    it "shows friendly error when OAuth ENV vars are missing" do
      get settings_storage_oauth_authorize_path(provider: "dropbox")

      expect(response).to redirect_to(settings_storage_path)
      follow_redirect!
      expect(response.body).to include("DROPBOX_CLIENT_ID")
    end
  end

  describe "GET /settings/storage/oauth/:provider/callback" do
    let(:oauth_manager) { instance_double(OAuthManager) }
    let(:state) { SecureRandom.hex(16) }

    before do
      allow(OAuthManager).to receive(:new).and_return(oauth_manager)
    end

    it "exchanges code for tokens and saves the setting" do
      allow(oauth_manager).to receive(:handle_callback).and_return({
        access_token: "access-123",
        refresh_token: "refresh-456",
        expires_at: 1.hour.from_now,
        token_type: "bearer"
      })

      # Stub authorize_url to capture the state, then set session state
      captured_state = nil
      allow(oauth_manager).to receive(:authorize_url) do |_provider, redirect_uri:|
        captured_state = SecureRandom.hex(16)
        { url: "https://www.dropbox.com/auth?state=#{captured_state}", state: captured_state }
      end

      get settings_storage_oauth_authorize_path(provider: "dropbox")

      get settings_storage_oauth_callback_path(provider: "dropbox"),
          params: { code: "auth-code", state: captured_state }

      expect(response).to redirect_to(settings_storage_path)
      follow_redirect!
      expect(response.body).to include("connected successfully")

      setting = StorageSetting.last
      expect(setting.provider).to eq("dropbox")
      expect(setting.config_data["access_token"]).to eq("access-123")
      expect(setting.status).to eq("ok")
    end

    it "rejects callback with mismatched state" do
      get settings_storage_oauth_callback_path(provider: "dropbox"),
          params: { code: "auth-code", state: "wrong-state" }

      expect(response).to redirect_to(settings_storage_path)
      follow_redirect!
      expect(response.body).to include("Invalid OAuth state")
    end

    it "handles provider error response" do
      get settings_storage_oauth_callback_path(provider: "dropbox"),
          params: { error: "access_denied", error_description: "User cancelled" }

      expect(response).to redirect_to(settings_storage_path)
      follow_redirect!
      expect(response.body).to include("Authorization denied")
      expect(response.body).to include("User cancelled")
    end

    it "handles token exchange failure" do
      allow(oauth_manager).to receive(:handle_callback)
        .and_raise(OAuthManager::TokenExchangeError, "Invalid code")

      # Stub authorize_url to capture the state
      captured_state = nil
      allow(oauth_manager).to receive(:authorize_url) do |_provider, redirect_uri:|
        captured_state = SecureRandom.hex(16)
        { url: "https://www.dropbox.com/auth?state=#{captured_state}", state: captured_state }
      end

      get settings_storage_oauth_authorize_path(provider: "dropbox")

      get settings_storage_oauth_callback_path(provider: "dropbox"),
          params: { code: "bad-code", state: captured_state }

      expect(response).to redirect_to(settings_storage_path)
      follow_redirect!
      expect(response.body).to include("OAuth error")
    end

    it "rejects callback for unknown providers" do
      get settings_storage_oauth_callback_path(provider: "ftp"),
          params: { code: "code", state: "state" }

      expect(response).to redirect_to(settings_storage_path)
    end
  end
end
