require "rails_helper"

RSpec.describe OAuthManager do
  subject(:manager) { described_class.new }

  describe "#authorize_url" do
    it "builds a Dropbox authorize URL with correct params" do
      allow(ENV).to receive(:fetch).with("DROPBOX_CLIENT_ID").and_return("db-client-id")

      result = manager.authorize_url("dropbox", redirect_uri: "http://localhost:3000/callback")

      uri = URI.parse(result[:url])
      params = URI.decode_www_form(uri.query).to_h

      expect(uri.host).to eq("www.dropbox.com")
      expect(params["client_id"]).to eq("db-client-id")
      expect(params["response_type"]).to eq("code")
      expect(params["redirect_uri"]).to eq("http://localhost:3000/callback")
      expect(params["token_access_type"]).to eq("offline")
      expect(result[:state]).to be_present
    end

    it "builds a Google Drive authorize URL with access_type=offline" do
      allow(ENV).to receive(:fetch).with("GOOGLE_DRIVE_CLIENT_ID").and_return("gd-client-id")

      result = manager.authorize_url("google_drive", redirect_uri: "http://localhost:3000/callback")

      uri = URI.parse(result[:url])
      params = URI.decode_www_form(uri.query).to_h

      expect(uri.host).to eq("accounts.google.com")
      expect(params["access_type"]).to eq("offline")
      expect(params["prompt"]).to eq("consent")
    end

    it "builds a OneDrive authorize URL" do
      allow(ENV).to receive(:fetch).with("ONEDRIVE_CLIENT_ID").and_return("od-client-id")

      result = manager.authorize_url("onedrive", redirect_uri: "http://localhost:3000/callback")

      uri = URI.parse(result[:url])
      params = URI.decode_www_form(uri.query).to_h

      expect(uri.host).to eq("login.microsoftonline.com")
      expect(params["scope"]).to eq("Files.ReadWrite offline_access")
    end

    it "raises ProviderNotSupported for unknown provider" do
      expect {
        manager.authorize_url("unknown", redirect_uri: "http://localhost:3000/callback")
      }.to raise_error(OAuthManager::ProviderNotSupported)
    end

    it "raises ConfigurationError when ENV var is missing" do
      expect {
        manager.authorize_url("dropbox", redirect_uri: "http://localhost:3000/callback")
      }.to raise_error(OAuthManager::ConfigurationError, /DROPBOX_CLIENT_ID/)
    end
  end

  describe "#handle_callback" do
    let(:http_client) { double("HTTP client") }

    before do
      allow(manager).to receive(:http_client).and_return(http_client)
      allow(ENV).to receive(:fetch).with("DROPBOX_CLIENT_ID").and_return("db-id")
      allow(ENV).to receive(:fetch).with("DROPBOX_CLIENT_SECRET").and_return("db-secret")
    end

    it "exchanges code for tokens" do
      response = double("HTTP response",
        status: 200,
        body: double(to_s: {
          access_token: "access-123",
          refresh_token: "refresh-456",
          expires_in: 14400,
          token_type: "bearer"
        }.to_json))

      allow(http_client).to receive(:post).and_return(response)

      result = manager.handle_callback("dropbox",
        code: "auth-code",
        redirect_uri: "http://localhost:3000/callback")

      expect(result[:access_token]).to eq("access-123")
      expect(result[:refresh_token]).to eq("refresh-456")
      expect(result[:token_type]).to eq("bearer")
      expect(result[:expires_at]).to be_within(5.seconds).of(Time.current + 14400.seconds)
    end

    it "raises TokenExchangeError on HTTP error" do
      response = double("HTTP response",
        status: 400,
        body: double(to_s: { error: "invalid_grant", error_description: "Code expired" }.to_json))

      allow(http_client).to receive(:post).and_return(response)

      expect {
        manager.handle_callback("dropbox", code: "bad-code", redirect_uri: "http://localhost:3000/callback")
      }.to raise_error(OAuthManager::TokenExchangeError, "Code expired")
    end
  end

  describe "#refresh_access_token" do
    let(:http_client) { double("HTTP client") }

    before do
      allow(manager).to receive(:http_client).and_return(http_client)
      allow(ENV).to receive(:fetch).with("DROPBOX_CLIENT_ID").and_return("db-id")
      allow(ENV).to receive(:fetch).with("DROPBOX_CLIENT_SECRET").and_return("db-secret")
    end

    it "refreshes an access token" do
      response = instance_double("HTTPX::Response",
        status: 200,
        body: double(to_s: {
          access_token: "new-access",
          expires_in: 14400
        }.to_json))

      allow(http_client).to receive(:post).and_return(response)

      result = manager.refresh_access_token("dropbox", refresh_token: "refresh-456")

      expect(result[:access_token]).to eq("new-access")
      expect(result[:refresh_token]).to eq("refresh-456") # original kept if not returned
      expect(result[:expires_at]).to be_within(5.seconds).of(Time.current + 14400.seconds)
    end

    it "raises TokenRefreshError on HTTP error" do
      response = double("HTTP response",
        status: 401,
        body: double(to_s: { error: "invalid_grant" }.to_json))

      allow(http_client).to receive(:post).and_return(response)

      expect {
        manager.refresh_access_token("dropbox", refresh_token: "bad-token")
      }.to raise_error(OAuthManager::TokenRefreshError)
    end
  end

  describe "#ensure_fresh_token!" do
    it "returns setting unchanged when token is not expired" do
      setting = build_stubbed_setting(
        provider: "dropbox",
        config_data: {
          "access_token" => "token",
          "refresh_token" => "refresh",
          "expires_at" => 1.hour.from_now.iso8601
        }
      )

      result = manager.ensure_fresh_token!(setting)
      expect(result).to eq(setting)
    end

    it "refreshes token when about to expire" do
      http_client = double("HTTP client")
      allow(manager).to receive(:http_client).and_return(http_client)
      allow(ENV).to receive(:fetch).with("DROPBOX_CLIENT_ID").and_return("db-id")
      allow(ENV).to receive(:fetch).with("DROPBOX_CLIENT_SECRET").and_return("db-secret")

      response = double("HTTP response",
        status: 200,
        body: double(to_s: {
          access_token: "new-access",
          expires_in: 14400
        }.to_json))
      allow(http_client).to receive(:post).and_return(response)

      setting = StorageSetting.create!(
        provider: "dropbox",
        active: true,
        config_data: {
          "access_token" => "old-access",
          "refresh_token" => "refresh-token",
          "expires_at" => 2.minutes.from_now.iso8601
        }
      )

      manager.ensure_fresh_token!(setting)
      setting.reload

      expect(setting.config_data["access_token"]).to eq("new-access")
    end

    it "returns setting unchanged for non-OAuth providers" do
      setting = build_stubbed_setting(provider: "s3", config_data: {})
      result = manager.ensure_fresh_token!(setting)
      expect(result).to eq(setting)
    end

    it "raises error when no refresh token available" do
      setting = build_stubbed_setting(
        provider: "dropbox",
        config_data: {
          "access_token" => "token",
          "expires_at" => 2.minutes.from_now.iso8601
        }
      )

      expect {
        manager.ensure_fresh_token!(setting)
      }.to raise_error(OAuthManager::TokenRefreshError, /No refresh token/)
    end
  end

  describe "#oauth_provider?" do
    it "returns true for known OAuth providers" do
      expect(manager.oauth_provider?("dropbox")).to be true
      expect(manager.oauth_provider?("google_drive")).to be true
      expect(manager.oauth_provider?("onedrive")).to be true
    end

    it "returns false for non-OAuth providers" do
      expect(manager.oauth_provider?("local")).to be false
      expect(manager.oauth_provider?("s3")).to be false
    end
  end

  private

  def build_stubbed_setting(provider:, config_data:)
    setting = instance_double(StorageSetting,
      provider: provider,
      config_data: config_data)
    setting
  end
end
