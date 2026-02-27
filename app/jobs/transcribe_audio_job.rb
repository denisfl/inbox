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
      whisper_language = ENV['WHISPER_LANGUAGE'].presence
      form_data = { audio: HTTP::FormData::File.new(temp_file.path) }
      form_data[:language] = whisper_language if whisper_language

      response = HTTP.timeout(300).post(
        "#{ENV.fetch('WHISPER_BASE_URL', 'http://whisper:5000')}/transcribe",
        form: form_data
      )

      unless response.status.success?
        Rails.logger.error("Whisper API error: #{response.status} - #{response.body}")
        raise "Whisper API returned #{response.status}"
      end

      data = JSON.parse(response.body)
      raw_transcription = data['text']
      detected_language = data['language'].presence

      # LLM correction pass (best-effort — falls back to raw on any error)
      transcription = correct_transcription(raw_transcription)

      # Update document title and add transcription block
      document.update!(title: transcription.truncate(50))

      # Build block content with raw text and detected language for reference
      block_content = { text: transcription, raw_text: raw_transcription }
      block_content[:language] = detected_language if detected_language

      # Add transcription text block before audio file
      document.blocks.create!(
        block_type: 'text',
        position: 0,
        content: block_content.to_json
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
      content: { text: "Transcription failed: #{e.message}" }.to_json
    )

    raise # Retry via Sidekiq
  end

  private

  def correct_transcription(raw_text)
    model = ENV.fetch('OLLAMA_CORRECTION_MODEL', 'llama3.2')
    prompt = <<~PROMPT
      You are a Russian speech recognition post-processor. Your ONLY job is minimal error correction.

      CORRECT only if ALL conditions are met:
      - The word is phonetically impossible or completely nonsensical in context
      - The correct form is unambiguous (only one possible fix)
      - The fix requires changing 1-2 characters maximum

      NEVER:
      - Add, remove, or reorder words
      - Change punctuation or capitalization
      - Rephrase or improve style
      - Add any prefix like "Corrected:" or "Here is:" before output
      - Change words that could be valid in any context (names, slang, domain terms)

      When in doubt — output the text unchanged.

      Examples:
      Input: "он сказал чо это невозможно"
      Output: "он сказал чо это невозможно"

      Input: "встреча в понедельник в десять чесов"
      Output: "встреча в понедельник в десять часов"

      Now process this text and output ONLY the result with no commentary:
      ###
      #{raw_text}
      ###
    PROMPT

    response = HTTP.timeout(60).post(
      "#{ENV.fetch('OLLAMA_BASE_URL', 'http://ollama:11434')}/api/generate",
      json: { model: model, prompt: prompt, stream: false }
    )

    unless response.status.success?
      Rails.logger.warn("Ollama correction returned #{response.status} — using raw transcription")
      return raw_text
    end

    data = JSON.parse(response.body)
    corrected = data['response']&.strip.presence
    corrected || raw_text
  rescue StandardError => e
    Rails.logger.warn("Transcription correction error (using raw): #{e.message}")
    raw_text
  end

  def notify_telegram_user(document, transcription)
    bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
    preview = transcription.truncate(100)

    bot.api.send_message(
      chat_id: document.telegram_chat_id,
      text: "Transcription complete:\n\n#{preview}"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to notify Telegram user: #{e.message}")
    # Don't raise - transcription succeeded even if notification failed
  end
end
