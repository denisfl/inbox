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

  private

  def generate_slug
    self.slug = title.parameterize
  end
end
