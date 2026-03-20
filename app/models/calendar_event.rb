# frozen_string_literal: true

class CalendarEvent < ApplicationRecord
  # ── Constants ──────────────────────────────────────────────────────────────
  STATUSES = %w[confirmed tentative cancelled].freeze
  SOURCES  = %w[google manual ical].freeze

  # Google Calendar color IDs → approximate hex values (for UI)
  GOOGLE_COLOR_MAP = {
    "1"  => "#a4bdfc", # Lavender
    "2"  => "#7ae7bf", # Sage
    "3"  => "#dbadff", # Grape
    "4"  => "#ff887c", # Flamingo
    "5"  => "#fbd75b", # Banana
    "6"  => "#ffb878", # Tangerine
    "7"  => "#46d6db", # Peacock
    "8"  => "#e1e1e1", # Graphite
    "9"  => "#5484ed", # Blueberry
    "10" => "#51b749", # Basil
    "11" => "#dc2127"  # Tomato
  }.freeze

  # ── Validations ────────────────────────────────────────────────────────────
  validates :google_event_id, presence: true, uniqueness: true, if: -> { source == "google" }
  validates :google_event_id, uniqueness: true, allow_nil: true, unless: -> { source == "google" }
  validates :title,           presence: true
  validates :starts_at,       presence: true
  validates :status,          inclusion: { in: STATUSES }
  validates :source,          inclusion: { in: SOURCES }

  # ── Associations ───────────────────────────────────────────────────────────
  has_many :calendar_event_tags, dependent: :destroy
  has_many :tags, through: :calendar_event_tags
  has_rich_text :description
  # ── Callbacks ──────────────────────────────────────────────────────────────
  before_validation :assign_local_uid, unless: -> { source == "google" }
  before_validation :normalize_event_times

  # ── Scopes ─────────────────────────────────────────────────────────────────
  scope :confirmed,   -> { where(status: "confirmed") }
  scope :google,      -> { where(source: "google") }
  scope :manual,      -> { where(source: "manual") }
  scope :ical,        -> { where(source: "ical") }
  scope :upcoming,    -> { confirmed.where("starts_at >= ?", Time.current).order(:starts_at) }
  scope :today,       -> { confirmed.where(starts_at: Time.current.beginning_of_day..Time.current.end_of_day).order(:starts_at) }
  scope :tomorrow,    -> { confirmed.where(starts_at: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day).order(:starts_at) }
  scope :this_week,   -> { confirmed.where(starts_at: Time.current..7.days.from_now.end_of_day).order(:starts_at) }
  scope :in_range,    ->(from, to) { confirmed.where(starts_at: from..to).order(:starts_at) }

  # Filter by multiple tags (AND — events must have ALL specified tags)
  scope :tagged_with, ->(tag_names) {
    return all if tag_names.blank?

    names = Array(tag_names).map { |n| n.to_s.strip.downcase }.reject(&:blank?)
    return all if names.empty?

    joins(:tags)
      .where(tags: { name: names })
      .group("calendar_events.id")
      .having("COUNT(DISTINCT tags.id) = ?", names.size)
  }

  # Events that need reminder: starting within the configured lead time, not yet reminded
  scope :needs_reminder, ->(lead_minutes = nil) {
    lead = (lead_minutes || ENV.fetch("CALENDAR_REMINDER_MINUTES", "10")).to_i
    confirmed
      .where(starts_at: Time.current..lead.minutes.from_now)
      .where(reminded_at: nil)
  }

  # ── Instance helpers ───────────────────────────────────────────────────────

  def duration_minutes
    return nil if ends_at.blank? || all_day?
    ((ends_at - starts_at) / 60).round
  end

  def duration_label
    mins = duration_minutes
    return nil unless mins
    if mins < 60
      "#{mins}m"
    else
      hours = mins / 60
      rem   = mins % 60
      rem > 0 ? "#{hours}h #{rem}m" : "#{hours}h"
    end
  end

  def display_color
    GOOGLE_COLOR_MAP.fetch(color.to_s, "#5484ed")
  end

  def time_label
    return "All day" if all_day?
    starts_at.strftime("%-H:%M")
  end

  # Returns events grouped by date (Date → [CalendarEvent])
  def self.grouped_by_day(events)
    events.group_by { |e| e.starts_at.to_date }
  end

  def past?
    return false if all_day?
    (ends_at || starts_at) < Time.current
  end

  def grid_row_start(day_start_hour: 7)
    return nil if all_day?
    offset_minutes = [ (starts_at.hour - day_start_hour) * 60 + starts_at.min, 0 ].max
    (offset_minutes / 30) + 1
  end

  def grid_row_span
    return 1 if all_day? || ends_at.blank?
    slots = (duration_minutes / 30.0).ceil
    [ slots, 1 ].max
  end

  # Can this event be edited/deleted through the web UI?
  def local?
    source != "google"
  end

  private

  def assign_local_uid
    self.google_event_id ||= "#{source}-#{SecureRandom.uuid}"
  end

  # Normalize all-day event times and ensure ends_at > starts_at.
  def normalize_event_times
    return unless starts_at.present?

    if all_day?
      self.starts_at = starts_at.beginning_of_day
      self.ends_at   = starts_at.end_of_day
    elsif ends_at.present? && ends_at <= starts_at
      self.ends_at = starts_at + 1.hour
    end
  end
end
