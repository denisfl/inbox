# frozen_string_literal: true

class Task < ApplicationRecord
  # ── Associations ──────────────────────────────────────────────────────────
  belongs_to :document, optional: true

  # ── Validations ───────────────────────────────────────────────────────────
  validates :title, presence: true
  validates :priority, inclusion: { in: %w[pinned high mid low] }
  validates :recurrence_rule, inclusion: { in: %w[daily weekly monthly yearly], allow_nil: true }

  # ── Callbacks ─────────────────────────────────────────────────────────────
  before_validation :normalize_recurrence_rule

  # ── Priority helpers ──────────────────────────────────────────────────────
  PRIORITIES = %w[pinned high mid low].freeze
  PRIORITY_ORDER = { "pinned" => 0, "high" => 1, "mid" => 2, "low" => 3 }.freeze

  # ── Scopes ────────────────────────────────────────────────────────────────
  scope :active,    -> { where(completed: false) }
  scope :completed, -> { where(completed: true) }
  scope :pinned,    -> { where(priority: "pinned") }

  # Due date scopes
  scope :today, -> {
    active.where(due_date: Date.current)
          .or(active.where(priority: "pinned"))
  }
  scope :upcoming, -> {
    active.where("due_date > ?", Date.current)
  }
  scope :inbox, -> {
    active.where(due_date: nil).where.not(priority: "pinned")
  }
  scope :overdue, -> {
    active.where("due_date < ?", Date.current)
  }
  scope :with_due_date, -> { where.not(due_date: nil) }

  # Date range scope for calendar integration
  scope :in_date_range, ->(from, to) {
    active.where(due_date: from..to)
  }

  # Default ordering: priority then position
  scope :ordered, -> {
    order(
      Arel.sql("CASE priority
        WHEN 'pinned' THEN 0
        WHEN 'high'   THEN 1
        WHEN 'mid'    THEN 2
        WHEN 'low'    THEN 3
        ELSE 4
      END"),
      :position,
      :created_at
    )
  }

  # ── Instance methods ──────────────────────────────────────────────────────

  def complete!
    transaction do
      update!(completed: true, completed_at: Time.current)
      spawn_next_recurrence! if recurrence_rule.present? && due_date.present?
    end
  end

  def uncomplete!
    update!(completed: false, completed_at: nil)
  end

  def toggle!
    completed? ? uncomplete! : complete!
  end

  def overdue?
    !completed? && due_date.present? && due_date < Date.current
  end

  def due_today?
    due_date == Date.current
  end

  def recurring?
    recurrence_rule.present?
  end

  private

  def spawn_next_recurrence!
    next_date = case recurrence_rule
                when "daily"   then due_date + 1.day
                when "weekly"  then due_date + 1.week
                when "monthly" then due_date + 1.month
                when "yearly"  then due_date + 1.year
                end

    return unless next_date

    Task.create!(
      title: title,
      description: description,
      due_date: next_date,
      due_time: due_time,
      priority: priority,
      recurrence_rule: recurrence_rule,
      position: position,
      document_id: document_id
    )
  end

  def normalize_recurrence_rule
    self.recurrence_rule = nil if recurrence_rule.blank?
  end
end
