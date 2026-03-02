class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Include Pagy backend
  include Pagy::Method

  # Single-user password authentication for web UI.
  # Named method so subcontrollers can skip it with: skip_before_action :authenticate_web_user!
  before_action :authenticate_web_user!
  before_action :load_sidebar_data

  private

  def authenticate_web_user!
    return unless Rails.env.production?

    # :nocov:
    web_password = ENV["WEB_PASSWORD"].to_s
    raise "WEB_PASSWORD environment variable must be set in production" if web_password.empty?

    authenticate_or_request_with_http_basic("Inbox") do |_name, password|
      ActiveSupport::SecurityUtils.secure_compare(password, web_password)
    end
    # :nocov:
  end

  # Load sidebar navigation data (counts, tags) for every web page.
  def load_sidebar_data
    @sidebar_counts = {
      documents: Document.count,
      tasks:     Task.active.count
    }
    @sidebar_tags = Tag.joins(:document_tags)
                       .select("tags.*, COUNT(document_tags.id) as docs_count")
                       .group("tags.id")
                       .order("docs_count DESC")
                       .limit(10)
  end
end
