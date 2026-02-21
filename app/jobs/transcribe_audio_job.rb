# frozen_string_literal: true

class TranscribeAudioJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(document_id, audio_blob_key)
    document = Document.find(document_id)
    
    # Find the audio file block
    audio_block = document.blocks.find_by(block_type: 'file')
    return unless audio_block&.file&.attached?

    # Download audio file from ActiveStorage
    audio_file = audio_block.file.download
    
    # Create temporary file for Whisper API
    temp_file = Tempfile.new(['voice', '.ogg'])
    begin
      temp_file.binmode
      temp_file.write(audio_file)
      temp_file.rewind

      # Call Whisper API
      response = HTTP.timeout(300).post(
        "#{ENV.fetch('WHISPER_BASE_URL', 'http://whisper:5000')}/transcribe",
        form: {
          audio: HTTP::FormData::File.new(temp_file.path),
          language: 'ru'
        }
      )

      unless response.status.success?
        Rails.logger.error("Whisper API error: #{response.status} - #{response.body}")
        raise "Whisper API returned #{response.status}"
      end

      data = JSON.parse(response.body)
      transcription = data['text']

      # Update document title and add transcription block
      document.update!(title: transcription.truncate(50))
      
      # Add transcription text block before audio file
      document.blocks.create!(
        block_type: 'text',
        position: 0,
        content: { text: transcription }.to_json
      )

      # Update audio block position
      audio_block.update!(position: 1)

      # Notify user via Telegram (if chat_id available)
      if document.telegram_chat_id.present?
        notify_telegram_user(document, transcription)
      end

      Rails.logger.info("Transcribed document #{document.id}: #{transcription.truncate(100)}")
    ensure
      temp_file.close
      temp_file.unlink
    end
  rescue HTTP::TimeoutError => e
    Rails.logger.error("Whisper timeout for document #{document_id}: #{e.message}")
    raise # Retry via Sidekiq
  rescue StandardError => e
    Rails.logger.error("Transcription failed for document #{document_id}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    
    # Update document with error message
    document = Document.find(document_id)
    document.blocks.create!(
      block_type: 'text',
      position: 0,
      content: { text: "❌ Transcription failed: #{e.message}" }.to_json
    )
    
    raise # Retry via Sidekiq
  end

  private

  def notify_telegram_user(document, transcription)
    bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
    preview = transcription.truncate(100)
    
    bot.api.send_message(
      chat_id: document.telegram_chat_id,
      text: "✅ Transcription complete:\n\n#{preview}"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to notify Telegram user: #{e.message}")
    # Don't raise - transcription succeeded even if notification failed
  end
end
