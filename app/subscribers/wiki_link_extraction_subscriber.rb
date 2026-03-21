# frozen_string_literal: true

# Extracts wiki-links from document body when documents are created or updated.
# Replaces the previous `after_save :extract_wiki_links` callback in Document.
class WikiLinkExtractionSubscriber < BaseSubscriber
  def call(event)
    document = Document.find_by(id: event.payload[:model_id])
    return unless document

    DocumentLinkExtractor.new(document).call
  end
end
