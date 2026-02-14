class Tag < ApplicationRecord
  # Associations
  has_many :document_tags, dependent: :destroy
  has_many :documents, through: :document_tags

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Callbacks
  before_validation :normalize_name

  # Scopes
  scope :popular, -> { joins(:document_tags).group(:id).order('COUNT(document_tags.id) DESC') }
  scope :alphabetical, -> { order(:name) }

  private

  def normalize_name
    self.name = name.downcase.strip if name.present?
  end
end
