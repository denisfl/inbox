# frozen_string_literal: true

module DashboardHelper
  # Short relative time label (e.g. "now", "5m", "3h", "2d")
  def time_ago_short(time)
    return "—" unless time

    time = Time.zone.parse(time) if time.is_a?(String)
    seconds = (Time.current - time).to_i
    case seconds
    when 0..59       then "now"
    when 60..3599    then "#{seconds / 60}m"
    when 3600..86399 then "#{seconds / 3600}h"
    when 86400..604_799 then "#{seconds / 86_400}d"
    else time.strftime("%-d %b")
    end
  end

  # Time-of-day greeting
  def greeting_text
    hour = Time.current.hour
    case hour
    when 5..11  then "Good morning"
    when 12..17 then "Good afternoon"
    when 18..22 then "Good evening"
    else "Good night"
    end
  end

  # Source badge CSS class
  def source_badge_class(source)
    case source
    when "telegram" then "source-badge tg"
    when "voice"    then "source-badge voice"
    else "source-badge"
    end
  end

  # Source display label
  def source_label(source)
    case source
    when "telegram" then "Telegram"
    when "web"      then "Manual"
    when "api"      then "API"
    else source&.capitalize || "Note"
    end
  end

  # Color for source dot in sidebar / notes list
  def source_dot_color(source)
    case source
    when "telegram" then "#1b4f8a"
    when "voice"    then "#2d6a4f"
    else "#a09890"
    end
  end

  # Default tag color fallback
  def tag_dot_color(tag)
    return tag.color if tag.color.present?

    case tag.name
    when /todo|task/i   then "#d74e4e"
    when /idea/i        then "#b08d00"
    when /urgent|asap/i then "#d74e4e"
    when /work/i        then "#2563eb"
    else "#78716c"
    end
  end

  # Event source badge
  def event_source_badge(event)
    case event.source
    when "google" then { text: "GCal", class: "tl-src gcal" }
    when "ical"   then { text: "iCal", class: "tl-src gcal" }
    else { text: "Manual", class: "tl-src manual" }
    end
  end

  # Mini-calendar: first weekday offset (Monday=0 .. Sunday=6)
  def cal_first_wday(date)
    (date.beginning_of_month.wday + 6) % 7
  end
end
