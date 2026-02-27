# frozen_string_literal: true

require 'telegram/bot'

class TelegramMessageHandler
  attr_reader :update, :message, :bot

  def initialize(update)
    @update = update
    @message = update.message
    @bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
  end

  def handle
    return unless message

    Rails.logger.info("Handling Telegram message type: #{message_type}")

    case message_type
    when :text
      handle_text
    when :photo
      handle_photo
    when :voice
      handle_voice
    when :audio
      handle_audio
    when :document
      handle_document
    else
      send_reply("❌ Unsupported message type")
    end
  rescue StandardError => e
    Rails.logger.error("Message handling error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    send_reply("❌ Error processing message: #{e.message}")
  end

  private

  def message_type
    return :text if message.text.present?
    return :photo if message.photo.present?
    return :voice if message.voice.present?
    return :audio if message.audio.present?
    return :document if message.document.present?
    :unknown
  end

  def handle_text
    result = IntentClassifierService.classify(message.text)
    doc = IntentRouter.dispatch(result, message.chat.id)

    # Update telegram_message_id after creation (IntentRouter doesn't have access to it)
    doc.update_columns(telegram_message_id: message.message_id) if doc&.persisted?

    Rails.logger.info("Created #{result.intent} document: #{doc&.id} (confidence: #{result.confidence})")
  end

  def handle_photo
    # Telegram sends multiple photo sizes, get the largest
    photo = message.photo.max_by(&:file_size)
    file_info = bot.api.get_file(file_id: photo.file_id)
    file_path = file_info.file_path

    # Download the photo
    file_url = "https://api.telegram.org/file/bot#{ENV['TELEGRAM_BOT_TOKEN']}/#{file_path}"
    downloaded_file = download_file(file_url)

    caption = message.caption || "Photo from Telegram"
    # Add timestamp to ensure unique slug
    title_with_timestamp = "#{caption} #{Time.current.to_i}"

    doc = Document.create!(
      title: title_with_timestamp.truncate(50),
      source: 'telegram',
      telegram_chat_id: message.chat.id,
      telegram_message_id: message.message_id
    )

    # Create image block
    image_block = doc.blocks.create!(
      block_type: 'image',
      position: 0,
      content: {}.to_json
    )

    # Attach image using ActiveStorage (use 'image' attachment for image blocks)
    image_block.image.attach(
      io: downloaded_file,
      filename: "telegram_photo_#{photo.file_id}.jpg",
      content_type: 'image/jpeg'
    )

    # Add caption as text block if present
    if message.caption.present?
      doc.blocks.create!(
        block_type: 'text',
        position: 1,
        content: { text: message.caption }.to_json
      )
    end

    send_reply("✅ Photo saved")
    Rails.logger.info("Created photo document: #{doc.id}")
  end

  def handle_voice
    file_info = bot.api.get_file(file_id: message.voice.file_id)
    file_path = file_info.file_path

    # Download voice file
    file_url = "https://api.telegram.org/file/bot#{ENV['TELEGRAM_BOT_TOKEN']}/#{file_path}"
    downloaded_file = download_file(file_url)

    # Add timestamp to ensure unique slug
    title = "🎤 Voice #{Time.current.to_i}"
    
    doc = Document.create!(
      title: title,
      source: 'telegram',
      telegram_chat_id: message.chat.id,
      telegram_message_id: message.message_id
    )

    # Create file block with voice attachment
    file_block = doc.blocks.create!(
      block_type: 'file',
      position: 0,
      content: { filename: "voice_#{message.voice.file_id}.ogg" }.to_json
    )

    file_block.file.attach(
      io: downloaded_file,
      filename: "voice_#{message.voice.file_id}.ogg",
      content_type: 'audio/ogg'
    )

    # Queue transcription job
    TranscribeAudioJob.perform_later(doc.id, file_block.file.blob.key)

    send_reply("🎤 Transcribing your voice note...")
    Rails.logger.info("Created voice document: #{doc.id}, queued transcription")
  end

  def handle_audio
    file_info = bot.api.get_file(file_id: message.audio.file_id)
    file_path = file_info.file_path

    # Download audio file
    file_url = "https://api.telegram.org/file/bot#{ENV['TELEGRAM_BOT_TOKEN']}/#{file_path}"
    downloaded_file = download_file(file_url)

    filename = message.audio.file_name || "audio_#{message.audio.file_id}"
    # Add timestamp to ensure unique slug
    title = "🎵 #{filename} #{Time.current.to_i}"

    doc = Document.create!(
      title: title.truncate(50),
      source: 'telegram',
      telegram_chat_id: message.chat.id,
      telegram_message_id: message.message_id
    )

    # Create file block with audio attachment
    file_block = doc.blocks.create!(
      block_type: 'file',
      position: 0,
      content: { filename: filename }.to_json
    )

    file_block.file.attach(
      io: downloaded_file,
      filename: filename,
      content_type: message.audio.mime_type || 'audio/mpeg'
    )

    send_reply("🎵 Audio file saved")
    Rails.logger.info("Created audio document: #{doc.id}")
  end

  def handle_document
    file_info = bot.api.get_file(file_id: message.document.file_id)
    file_path = file_info.file_path

    # Download document
    file_url = "https://api.telegram.org/file/bot#{ENV['TELEGRAM_BOT_TOKEN']}/#{file_path}"
    downloaded_file = download_file(file_url)

    filename = message.document.file_name
    caption = message.caption || filename

    doc = Document.create!(
      title: caption.truncate(50),
      source: 'telegram',
      telegram_chat_id: message.chat.id,
      telegram_message_id: message.message_id
    )

    # Create file block
    file_block = doc.blocks.create!(
      block_type: 'file',
      position: 0,
      content: { filename: filename }.to_json
    )

    file_block.file.attach(
      io: downloaded_file,
      filename: filename,
      content_type: message.document.mime_type
    )

    # Add caption as text block if present
    if message.caption.present?
      doc.blocks.create!(
        block_type: 'text',
        position: 1,
        content: { text: message.caption }.to_json
      )
    end

    send_reply("✅ Document saved")
    Rails.logger.info("Created document: #{doc.id}")
  end

  def download_file(url)
    require 'open-uri'

    URI.parse(url).open
  rescue StandardError => e
    Rails.logger.error("Failed to download file from #{url}: #{e.message}")
    raise "❌ Failed to download file: #{e.message}"
  end

  def send_reply(text)
    bot.api.send_message(
      chat_id: message.chat.id,
      text: text,
      reply_to_message_id: message.message_id
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send reply: #{e.message}")
  end
end
