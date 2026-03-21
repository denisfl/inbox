# frozen_string_literal: true

# Register all domain event subscribers at boot.
Rails.application.config.after_initialize do
  WikiLinkExtractionSubscriber.subscribe("document.created")
  WikiLinkExtractionSubscriber.subscribe("document.updated")
end
