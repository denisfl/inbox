class Block < ApplicationRecord
  # Associations
  belongs_to :document

  # Active Storage attachments
  has_one_attached :image
  has_one_attached :file

  # Validations
  validates :block_type, presence: true
  # Allow nil position on create (set_default_position callback will assign it)
  validates :position,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  # Block types enumeration
  BLOCK_TYPES = %w[
    text
    heading
    todo
    image
    code
    quote
    link
    file
  ].freeze

  validates :block_type, inclusion: { in: BLOCK_TYPES }

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :by_type, ->(type) { where(block_type: type) }

  # Callbacks
  before_validation :set_default_position, if: -> { position.nil? }, on: :create

  # Content helpers
  def content_hash
    content.present? ? JSON.parse(content) : {}
  rescue JSON::ParserError
    {}
  end

  def content_hash=(hash)
    self.content = hash.to_json
  end

  private

  def set_default_position
    return unless document_id

    max_position = Block.where(document_id: document_id).maximum(:position)
    self.position = max_position ? max_position + 1 : 0
  end
end
