# frozen_string_literal: true

# Checks for upcoming calendar events and sends Telegram reminders.
# Runs every minute via SolidQueue recurring schedule.
#
# Reminds when event starts within CALENDAR_REMINDER_MINUTES (default: 10).
class SendEventReminderJob < ApplicationJob
  queue_as :default

  # Don't retry — if we miss a window, a duplicate reminder next minute is worse
  discard_on StandardError do |_job, error|
    Rails.logger.error("[SendEventReminderJob] discarded after error: #{error.message}")
  end

  def perform
    lead_minutes = ENV.fetch("CALENDAR_REMINDER_MINUTES", "10").to_i
    events = CalendarEvent.needs_reminder(lead_minutes)

    return if events.none?

    events.each do |event|
      send_reminder(event, lead_minutes)
    end
  end

  private

  def send_reminder(event, lead_minutes)
    minutes_away = ((event.starts_at - Time.current) / 60).round
    time_str     = event.starts_at.strftime("%-H:%M")

    text = "⏰ <b>#{CGI.escapeHTML(event.title)}</b> starts in #{minutes_away} min (#{time_str})"
    text += "\n⏱ #{event.duration_label}" if event.duration_label.present?
    text += "\n🔗 <a href=\"#{event.html_link}\">Open in Calendar</a>" if event.html_link.present?

    send_telegram(text)
    event.update_column(:reminded_at, Time.current)
    Rails.logger.info("[SendEventReminderJob] reminded: #{event.title} (#{event.starts_at})")
  rescue StandardError => e
    Rails.logger.error("[SendEventReminderJob] failed for event #{event.id}: #{e.message}")
  end

  def send_telegram(text)
    token   = ENV.fetch("TELEGRAM_BOT_TOKEN")
    chat_id = ENV.fetch("TELEGRAM_ALLOWED_USER_ID")

    uri  = URI("https://api.telegram.org/bot#{token}/sendMessage")
    body = { chat_id: chat_id, text: text, parse_mode: "HTML" }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = body
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Telegram API error #{response.code}: #{response.body}"
    end
  end
end
