# frozen_string_literal: true

class TranscribeAudioJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(document_id, audio_blob_key)
    document = Document.find(document_id)

    # Find the audio file block
    audio_block = document.blocks.find_by(block_type: "file")
    return unless audio_block&.file&.attached?

    # Download audio file from ActiveStorage
    audio_file = audio_block.file.download

    # Create temporary file for transcription API
    temp_file = Tempfile.new([ "voice", ".ogg" ])
    begin
      temp_file.binmode
      temp_file.write(audio_file)
      temp_file.rewind

      # Call Parakeet v3 transcription API
      # Parakeet handles punctuation and capitalization natively — no LLM needed
      transcriber_language = ENV["TRANSCRIBER_LANGUAGE"].presence
      form_data = { audio: HTTP::FormData::File.new(temp_file.path) }
      form_data[:language] = transcriber_language if transcriber_language

      response = HTTP.timeout(600).post(
        "#{ENV.fetch('TRANSCRIBER_URL', 'http://transcriber:5000')}/transcribe",
        form: form_data
      )

      unless response.status.success?
        Rails.logger.error("Transcription API error: #{response.status} - #{response.body}")
        raise "Transcription API returned #{response.status}"
      end

      data = JSON.parse(response.body)
      transcription = data["text"].to_s.strip

      if transcription.blank?
        Rails.logger.warn("Empty transcription for document #{document_id}")
        transcription = "(empty transcription)"
      end

      # Update document title and save as note
      document.update!(
        title: transcription.truncate(50),
        document_type: "note"
      )

      # Build block content
      block_content = { text: transcription }
      block_content[:language] = data["language"] if data["language"].present?

      # Add transcription text block before audio file
      document.blocks.create!(
        block_type: "text",
        position: 0,
        content: block_content.to_json
      )

      # Update audio block position
      audio_block.update!(position: 1)

      # Notify user via Telegram
      if document.telegram_chat_id.present?
        notify_telegram_user(document, transcription)
      end

      Rails.logger.info("Transcribed document #{document.id}: #{transcription.truncate(100)}")
    ensure
      temp_file.close
      temp_file.unlink
    end
  rescue HTTP::TimeoutError => e
    Rails.logger.error("Transcription timeout for document #{document_id}: #{e.message}")
    raise # Retry via Sidekiq
  rescue StandardError => e
    Rails.logger.error("Transcription failed for document #{document_id}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    # Update document with error message
    document = Document.find(document_id)
    document.blocks.create!(
      block_type: "text",
      position: 0,
      content: { text: "Transcription failed: #{e.message}" }.to_json
    )

    raise # Retry via Sidekiq
  end

  private

  def notify_telegram_user(document, transcription)
    bot = Telegram::Bot::Client.new(ENV["TELEGRAM_BOT_TOKEN"])
    preview = transcription.truncate(100)

    bot.api.send_message(
      chat_id: document.telegram_chat_id,
      text: "Note saved\n\n#{preview}"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to notify Telegram user: #{e.message}")
    # Don't raise - transcription succeeded even if notification failed
  end
end
