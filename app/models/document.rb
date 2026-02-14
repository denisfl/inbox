class Document < ApplicationRecord
  # Associations
  has_many :blocks, dependent: :destroy
  has_many :document_tags, dependent: :destroy
  has_many :tags, through: :document_tags

  # Validations
  validates :title, presence: true
  validates :slug, uniqueness: true, allow_blank: true

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? && title.present? }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_source, ->(source) { where(source: source) }

  # Full-text search using SQLite FTS5
  def self.search(query, page: 1, per_page: 20)
    return none if query.blank?

    # Sanitize query for FTS5 (escape special characters)
    sanitized_query = query.gsub(/[^a-zA-Z0-9\s]/, ' ')

    # Search in FTS table
    sql = <<-SQL
      SELECT
        d.*,
        snippet(documents_fts, 1, '<mark>', '</mark>', '...', 30) as title_snippet,
        snippet(documents_fts, 2, '<mark>', '</mark>', '...', 60) as content_snippet,
        bm25(documents_fts) as rank
      FROM documents d
      INNER JOIN documents_fts fts ON fts.document_id = d.id
      WHERE documents_fts MATCH ?
      ORDER BY rank
      LIMIT ? OFFSET ?
    SQL

    offset = (page - 1) * per_page

    # Execute raw SQL and map to Document objects
    results = connection.select_all(
      sanitize_sql([sql, sanitized_query, per_page, offset])
    )

    # Convert to Document objects with snippet attributes
    results.map do |row|
      doc = find(row['id'])
      doc.define_singleton_method(:title_snippet) { row['title_snippet'] }
      doc.define_singleton_method(:content_snippet) { row['content_snippet'] }
      doc.define_singleton_method(:rank) { row['rank'] }
      doc
    end
  end

  # Count search results
  def self.search_count(query)
    return 0 if query.blank?

    sanitized_query = query.gsub(/[^a-zA-Z0-9\s]/, ' ')

    sql = <<-SQL
      SELECT COUNT(*) as count
      FROM documents_fts
      WHERE documents_fts MATCH ?
    SQL

    connection.select_value(sanitize_sql([sql, sanitized_query]))
  end

  private

  def generate_slug
    self.slug = title.parameterize
  end
end
