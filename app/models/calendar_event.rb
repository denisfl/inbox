# frozen_string_literal: true

class CalendarEvent < ApplicationRecord
  # ── Constants ──────────────────────────────────────────────────────────────
  STATUSES = %w[confirmed tentative cancelled].freeze

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
  validates :google_event_id, presence: true, uniqueness: true
  validates :title,           presence: true
  validates :starts_at,       presence: true
  validates :status,          inclusion: { in: STATUSES }

  # ── Scopes ─────────────────────────────────────────────────────────────────
  scope :confirmed,   -> { where(status: "confirmed") }
  scope :upcoming,    -> { confirmed.where("starts_at >= ?", Time.current).order(:starts_at) }
  scope :today,       -> { confirmed.where(starts_at: Time.current.beginning_of_day..Time.current.end_of_day).order(:starts_at) }
  scope :tomorrow,    -> { confirmed.where(starts_at: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day).order(:starts_at) }
  scope :this_week,   -> { confirmed.where(starts_at: Time.current..7.days.from_now.end_of_day).order(:starts_at) }
  scope :in_range,    ->(from, to) { confirmed.where(starts_at: from..to).order(:starts_at) }

  # Events that need reminder: starting in 10–30 min, not yet reminded
  scope :needs_reminder, -> {
    confirmed
      .where(starts_at: 9.minutes.from_now..31.minutes.from_now)
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
end
