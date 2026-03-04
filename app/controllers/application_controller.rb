class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Include Pagy backend
  include Pagy::Method

  # Single-user password authentication for web UI.
  # Named method so subcontrollers can skip it with: skip_before_action :authenticate_web_user!
  before_action :authenticate_web_user!
  before_action :load_sidebar_data
  before_action :set_cache_headers

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
    @sidebar_tags = Tag.left_joins(:document_tags, :task_tags, :calendar_event_tags)
                       .select(
                         "tags.*",
                         "COUNT(DISTINCT document_tags.id) as docs_count",
                         "COUNT(DISTINCT task_tags.id) as tasks_count",
                         "COUNT(DISTINCT calendar_event_tags.id) as events_count",
                         "COUNT(DISTINCT document_tags.id) + COUNT(DISTINCT task_tags.id) + COUNT(DISTINCT calendar_event_tags.id) as total_count"
                       )
                       .group("tags.id")
                       .having("COUNT(DISTINCT document_tags.id) + COUNT(DISTINCT task_tags.id) + COUNT(DISTINCT calendar_event_tags.id) > 0")
                       .order("total_count DESC")
                       .limit(10)
  end

  # Prevent browsers and mobile WebViews from caching HTML responses.
  # Static assets are fingerprinted by Propshaft and cached at the HTTP level.
  def set_cache_headers
    return unless request.format.html?

    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end
end
