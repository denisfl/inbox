module Settings
  class StorageOAuthController < ApplicationController
    ALLOWED_PROVIDERS = %w[dropbox google_drive onedrive].freeze

    before_action :validate_provider

    def authorize
      oauth = OAuthManager.new
      result = oauth.authorize_url(provider,
        redirect_uri: callback_url)

      session[:oauth_state] = result[:state]
      redirect_to result[:url], allow_other_host: true
    rescue OAuthManager::ConfigurationError => e
      redirect_to settings_storage_path, alert: e.message
    end

    def callback
      if params[:error].present?
        redirect_to settings_storage_path, alert: "Authorization denied: #{params[:error_description] || params[:error]}"
        return
      end

      if params[:state] != session.delete(:oauth_state)
        redirect_to settings_storage_path, alert: "Invalid OAuth state. Please try again."
        return
      end

      oauth = OAuthManager.new
      tokens = oauth.handle_callback(provider,
        code: params[:code],
        redirect_uri: callback_url)

      setting = StorageSetting.active_setting || StorageSetting.new
      setting.provider = provider
      setting.active = true
      config = setting.config_data || {}
      config["access_token"] = tokens[:access_token]
      config["refresh_token"] = tokens[:refresh_token]
      config["expires_at"] = tokens[:expires_at]&.iso8601
      setting.config_data = config
      setting.status = "ok"
      setting.last_checked_at = Time.current
      setting.save!

      redirect_to settings_storage_path, notice: "#{provider.titleize} connected successfully."
    rescue OAuthManager::TokenExchangeError => e
      redirect_to settings_storage_path, alert: "OAuth error: #{e.message}"
    end

    private

    def provider
      params[:provider]
    end

    def validate_provider
      return if ALLOWED_PROVIDERS.include?(provider)

      redirect_to settings_storage_path, alert: "Unknown provider: #{provider}"
    end

    def callback_url
      settings_storage_oauth_callback_url(provider: provider)
    end
  end
end
