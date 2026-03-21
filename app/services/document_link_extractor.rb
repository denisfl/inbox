class DocumentLinkExtractor
  WIKI_LINK_PATTERN = /\[\[([^\[\]]+)\]\]/

  def initialize(document)
    @document = document
  end

  def call
    titles = extract_titles
    target_ids = resolve_target_ids(titles)

    @document.outgoing_links.delete_all
    target_ids.each do |target_id|
      @document.outgoing_links.create!(target_document_id: target_id)
    end
    @document.outgoing_links.reset
  end

  private

  def extract_titles
    plain_text = @document.body&.to_plain_text.to_s
    plain_text.scan(WIKI_LINK_PATTERN).flatten.map(&:strip).uniq
  end

  def resolve_target_ids(titles)
    return [] if titles.empty?

    downcased = titles.map { |t| t.encode(Encoding::UTF_8).gsub(/[A-Z]/) { |c| c.downcase } }
    Document
      .where("title IN (?) OR LOWER(title) IN (?)", titles, downcased)
      .where.not(id: @document.id)
      .pluck(:id)
  end
end
