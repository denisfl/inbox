# frozen_string_literal: true

require "telegram/bot"

# Transcribes audio attachments via Parakeet v3 (onnx-asr) and saves the text.
#
# Retry strategy:
#   - retry_on StandardError: 3 attempts with exponential backoff (transient failures)
#   - 413 (audio too long): treated as permanent failure — saves error message, no retry
#   - ExternalServiceClient handles HTTP-level retries (timeout, connection errors)
class TranscribeAudioJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

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

      # Call Parakeet v3 transcription API via ExternalServiceClient.
      # Timeout is configurable via TRANSCRIBER_TIMEOUT env (default: 600s).
      transcriber_language = ENV["TRANSCRIBER_LANGUAGE"].presence
      form_data = { audio: HTTP::FormData::File.new(temp_file.path) }
      form_data[:language] = transcriber_language if transcriber_language

      client = ExternalServiceClient.new(:transcriber)
      transcriber_url = ENV.fetch("TRANSCRIBER_URL", "http://transcriber:5000")
      response = client.post("#{transcriber_url}/transcribe", form: form_data)

      unless response.status.success?
        error_body = begin
          JSON.parse(response.body)["error"]
        rescue
          response.body.to_s.truncate(200)
        end

        Rails.logger.tagged("[transcriber]") do
          Rails.logger.error("Transcription API error: #{response.status} - #{error_body}")
        end

        # 413 = audio too long — permanent failure, don't retry
        if response.status.code == 413
          document.update!(title: document.title.start_with?("Voice") ? "Audio too long" : document.title)
          document.blocks.create!(
            block_type: "text",
            position: 0,
            content: { text: "Transcription skipped: #{error_body}" }.to_json
          )

          if document.telegram_chat_id.present?
            notify_telegram_user(document, "Transcription skipped: #{error_body}")
          end

          return # Don't retry
        end

        raise "Transcription API returned #{response.status}"
      end

      data = JSON.parse(response.body)
      transcription = data["text"].to_s.strip

      if transcription.blank?
        Rails.logger.tagged("[transcriber]") { Rails.logger.warn("Empty transcription for document #{document_id}") }
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

      Rails.logger.tagged("[transcriber]") do
        Rails.logger.info("Transcribed document #{document.id}: #{transcription.truncate(100)}")
      end
    ensure
      temp_file.close
      temp_file.unlink
    end
  rescue HTTP::TimeoutError => e
    Rails.logger.tagged("[transcriber]") do
      Rails.logger.error("Transcription timeout for document #{document_id}: #{e.message}")
    end
    raise # Retry via ActiveJob
  rescue StandardError => e
    Rails.logger.tagged("[transcriber]") do
      Rails.logger.error("Transcription failed for document #{document_id}: #{e.class} - #{e.message}")
    end

    # Update document with error message
    document = Document.find(document_id)
    document.blocks.create!(
      block_type: "text",
      position: 0,
      content: { text: "Transcription failed: #{e.message}" }.to_json
    )

    raise # Retry via ActiveJob
  end

  private

  def notify_telegram_user(document, transcription)
    bot = Telegram::Bot::Client.new(AppSecret["TELEGRAM_BOT_TOKEN"])
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
