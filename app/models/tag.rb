class Tag < ApplicationRecord
  # Associations
  has_many :document_tags, dependent: :destroy
  has_many :documents, through: :document_tags
  has_many :task_tags, dependent: :destroy
  has_many :tasks, through: :task_tags
  has_many :calendar_event_tags, dependent: :destroy
  has_many :calendar_events, through: :calendar_event_tags

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Callbacks
  before_validation :normalize_name

  # Scopes
  scope :popular, -> {
    left_joins(:document_tags, :task_tags, :calendar_event_tags)
      .group(:id)
      .order(Arel.sql("COUNT(DISTINCT document_tags.id) + COUNT(DISTINCT task_tags.id) + COUNT(DISTINCT calendar_event_tags.id) DESC"))
  }
  scope :alphabetical, -> { order(:name) }

  # Total items count across documents, tasks, and calendar events
  def items_count
    documents.count + tasks.count + calendar_events.count
  end

  private

  def normalize_name
    self.name = name.downcase.strip if name.present?
  end
end
