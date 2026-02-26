class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Include Pagy backend
  include Pagy::Backend

  # Single-user password authentication for web UI
  # Password is set via WEB_PASSWORD environment variable
  if Rails.env.production?
    raise "WEB_PASSWORD must be set in production" if ENV["WEB_PASSWORD"].blank?
    http_basic_authenticate_with name: "_", password: ENV["WEB_PASSWORD"]
  end
end
