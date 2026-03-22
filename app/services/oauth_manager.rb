class OAuthManager
  PROVIDERS = {
    dropbox: {
      authorize_url: "https://www.dropbox.com/oauth2/authorize",
      token_url: "https://api.dropboxapi.com/oauth2/token",
      scopes: "files.content.write files.content.read",
      client_id_env: "DROPBOX_CLIENT_ID",
      client_secret_env: "DROPBOX_CLIENT_SECRET",
      token_access_type: "offline"
    },
    google_drive: {
      authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
      token_url: "https://oauth2.googleapis.com/token",
      scopes: "https://www.googleapis.com/auth/drive.file",
      client_id_env: "GOOGLE_DRIVE_CLIENT_ID",
      client_secret_env: "GOOGLE_DRIVE_CLIENT_SECRET",
      extra_authorize_params: { access_type: "offline", prompt: "consent" }
    },
    onedrive: {
      authorize_url: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
      token_url: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
      scopes: "Files.ReadWrite offline_access",
      client_id_env: "ONEDRIVE_CLIENT_ID",
      client_secret_env: "ONEDRIVE_CLIENT_SECRET"
    }
  }.freeze

  class Error < StandardError; end
  class ProviderNotSupported < Error; end
  class ConfigurationError < Error; end
  class TokenExchangeError < Error; end
  class TokenRefreshError < Error; end

  def authorize_url(provider, redirect_uri:)
    config = provider_config!(provider)

    params = {
      client_id: client_id(config),
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: config[:scopes]
    }

    # Dropbox uses token_access_type for offline access
    params[:token_access_type] = config[:token_access_type] if config[:token_access_type]

    # Google uses extra params (access_type, prompt)
    params.merge!(config[:extra_authorize_params]) if config[:extra_authorize_params]

    # State parameter for CSRF protection
    params[:state] = SecureRandom.hex(16)

    uri = URI(config[:authorize_url])
    uri.query = URI.encode_www_form(params)

    { url: uri.to_s, state: params[:state] }
  end

  def handle_callback(provider, code:, redirect_uri:)
    config = provider_config!(provider)

    response = http_client.post(
      config[:token_url],
      form: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_id: client_id(config),
        client_secret: client_secret(config)
      }
    )

    body = parse_response!(response, TokenExchangeError)

    {
      access_token: body["access_token"],
      refresh_token: body["refresh_token"],
      expires_at: body["expires_in"] ? Time.current + body["expires_in"].to_i.seconds : nil,
      token_type: body["token_type"]
    }
  end

  def refresh_access_token(provider, refresh_token:)
    config = provider_config!(provider)

    response = http_client.post(
      config[:token_url],
      form: {
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: client_id(config),
        client_secret: client_secret(config)
      }
    )

    body = parse_response!(response, TokenRefreshError)

    {
      access_token: body["access_token"],
      refresh_token: body["refresh_token"] || refresh_token,
      expires_at: body["expires_in"] ? Time.current + body["expires_in"].to_i.seconds : nil
    }
  end

  def revoke(provider, token:)
    case provider.to_sym
    when :dropbox
      http_client
        .auth("Bearer #{token}")
        .post("https://api.dropboxapi.com/2/auth/token/revoke")
    when :google_drive
      http_client.post("https://oauth2.googleapis.com/revoke", form: { token: token })
    when :onedrive
      # Microsoft Graph doesn't support programmatic token revocation
      # Users must revoke via https://myapps.microsoft.com
      true
    else
      raise ProviderNotSupported, "Unknown provider: #{provider}"
    end
  end

  def ensure_fresh_token!(setting)
    return setting unless oauth_provider?(setting.provider)

    config_data = setting.config_data
    expires_at = config_data["expires_at"]

    return setting if expires_at.blank?
    return setting if Time.parse(expires_at) > 5.minutes.from_now

    refresh_token = config_data["refresh_token"]
    raise TokenRefreshError, "No refresh token available for #{setting.provider}" if refresh_token.blank?

    tokens = refresh_access_token(setting.provider, refresh_token: refresh_token)
    config_data["access_token"] = tokens[:access_token]
    config_data["refresh_token"] = tokens[:refresh_token]
    config_data["expires_at"] = tokens[:expires_at]&.iso8601
    setting.update!(config_data: config_data)
    setting
  end

  def oauth_provider?(provider)
    PROVIDERS.key?(provider.to_sym)
  end

  private

  def provider_config!(provider)
    key = provider.to_sym
    raise ProviderNotSupported, "Unknown OAuth provider: #{provider}" unless PROVIDERS.key?(key)
    PROVIDERS[key]
  end

  def client_id(config)
    ENV.fetch(config[:client_id_env])
  rescue KeyError
    raise ConfigurationError, "Missing ENV variable #{config[:client_id_env]}. Set it in your .env file or Docker environment."
  end

  def client_secret(config)
    ENV.fetch(config[:client_secret_env])
  rescue KeyError
    raise ConfigurationError, "Missing ENV variable #{config[:client_secret_env]}. Set it in your .env file or Docker environment."
  end

  def http_client
    @http_client ||= HTTP.timeout(10)
  end

  def parse_response!(response, error_class)
    body = JSON.parse(response.body.to_s)

    if response.status >= 400
      error_msg = body["error_description"] || body["error"] || "HTTP #{response.status}"
      raise error_class, error_msg
    end

    body
  rescue JSON::ParserError
    raise error_class, "Invalid response from OAuth provider: #{response.status}"
  end
end
