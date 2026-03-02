# frozen_string_literal: true

class IntentRouter
  def self.dispatch(result, telegram_chat_id)
    new.dispatch(result, telegram_chat_id)
  end

  def dispatch(result, telegram_chat_id)
    Rails.logger.info("IntentRouter: intent=#{result.intent} confidence=#{result.confidence} chat=#{telegram_chat_id}")

    case result.intent
    when "todo"  then create_todo(result, telegram_chat_id)
    when "event" then create_event(result, telegram_chat_id)
    else              create_note(result, telegram_chat_id)
    end
  end

  private

  def create_todo(result, telegram_chat_id)
    task = Task.create!(
      title: result.title,
      description: result.body,
      due_date: result.due_at&.to_date,
      due_time: result.due_at
    )
    reply(telegram_chat_id, "✅ Task added: #{result.title}")
    Rails.logger.info("IntentRouter: created task #{task.id}")
    task
  end

  def create_event(result, telegram_chat_id)
    # CalendarEvent model is not yet implemented (google-calendar story).
    # For now, create a document tagged #event as a note.
    document = Document.create!(
      title: result.title,
      document_type: "note",
      telegram_chat_id: telegram_chat_id
    )
    document.blocks.create!(
      block_type: "text",
      position: 0,
      content: { text: result.body, due_at: result.due_at&.iso8601 }.compact.to_json
    )
    # Auto-tag as telegram + event
    telegram_tag = Tag.find_or_create_by!(name: "telegram")
    document.tags << telegram_tag unless document.tags.include?(telegram_tag)
    tag = Tag.find_or_create_by!(name: "event")
    document.tags << tag unless document.tags.include?(tag)

    time_str = result.due_at ? result.due_at.strftime("%d.%m %H:%M") : "??"
    reply(telegram_chat_id, "📅 Event saved: #{result.title} on #{time_str}")
    Rails.logger.info("IntentRouter: created event document #{document.id}")
    document
  rescue StandardError => e
    Rails.logger.warn("IntentRouter: event creation failed (#{e.message}), falling back to note")
    create_note(result, telegram_chat_id)
  end

  def create_note(result, telegram_chat_id)
    document = Document.create!(
      title: result.title,
      document_type: "note",
      telegram_chat_id: telegram_chat_id
    )
    document.blocks.create!(
      block_type: "text",
      position: 0,
      content: { text: result.body }.to_json
    )
    # Auto-tag as telegram
    telegram_tag = Tag.find_or_create_by!(name: "telegram")
    document.tags << telegram_tag unless document.tags.include?(telegram_tag)
    reply(telegram_chat_id, "📝 Note saved")
    Rails.logger.info("IntentRouter: created note document #{document.id}")
    document
  end

  def reply(chat_id, text)
    return unless chat_id.present?

    bot = Telegram::Bot::Client.new(ENV["TELEGRAM_BOT_TOKEN"])
    bot.api.send_message(chat_id: chat_id, text: text)
  rescue StandardError => e
    Rails.logger.error("IntentRouter: failed to send Telegram reply: #{e.message}")
  end
end
