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
      transcription = correct_transcription(raw_transcription, detected_language)

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

  def correct_transcription(raw_text, detected_language = nil)
    model = ENV.fetch('OLLAMA_CORRECTION_MODEL', 'gemma3:4b')

    # Determine language context for the prompt.
    # Default/priority is Russian; fall back to Russian when language is unknown.
    lang_label = case detected_language
                 when 'en' then 'English'
                 else 'Russian'
                 end

    prompt = <<~PROMPT
      TASK: Fix obvious speech recognition errors in the #{lang_label} text below.

      OUTPUT RULES (MANDATORY):
      - Output ONLY the corrected text, nothing else
      - No explanations, no options, no comments, no formatting, no prefixes
      - Keep every word. Do not add or remove words.
      - Keep original punctuation and capitalization.
      - If a word looks wrong but you are not 100% sure, keep it as-is.
      - Fix only clear phonetic transcription errors (1-2 character typos).

      EXAMPLES OF CORRECT BEHAVIOR:
      #{correction_examples(detected_language)}

      TEXT TO FIX:
      #{raw_text}
    PROMPT

    timeout_seconds = ENV.fetch('OLLAMA_CORRECTION_TIMEOUT', '300').to_i
    response = HTTP.timeout(timeout_seconds).post(
      "#{ENV.fetch('OLLAMA_BASE_URL', 'http://ollama:11434')}/api/generate",
      json: { model: model, prompt: prompt, stream: false }
    )

    unless response.status.success?
      Rails.logger.warn("Ollama correction returned #{response.status} — using raw transcription")
      return raw_text
    end

    data = JSON.parse(response.body)
    corrected = data['response']&.strip.presence

    # Safety check: if response is suspiciously long vs input, it's likely chatty — discard
    if corrected && corrected.length > raw_text.length * 1.5
      Rails.logger.warn("Ollama correction response too long (#{corrected.length} vs #{raw_text.length}) — using raw")
      return raw_text
    end

    corrected || raw_text
  rescue StandardError => e
    Rails.logger.warn("Transcription correction error (using raw): #{e.message}")
    raw_text
  end

  def correction_examples(detected_language)
    if detected_language == 'en'
      <<~EXAMPLES
        Input:  "i went to the stor to buy bred and milke"
        Output: "i went to the stor to buy bred and milke"
        (explanation: uncertain words kept as-is)

        Input:  "the meeting is schedled for monday"
        Output: "the meeting is scheduled for monday"
        (explanation: "schedled" → "scheduled" — clear typo)

        Input:  "please send the reprot by tomorrow"
        Output: "please send the report by tomorrow"
        (explanation: "reprot" → "report" — clear typo)
      EXAMPLES
    else
      <<~EXAMPLES
        Input:  "встреча в понедельник в десять чесов"
        Output: "встреча в понедельник в десять часов"
        (explanation: "чесов" → "часов" — clear typo)

        Input:  "нужно купить хлеп и малако"
        Output: "нужно купить хлеп и малако"
        (explanation: uncertain words kept as-is)

        Input:  "он сказал чо это невозможно"
        Output: "он сказал чо это невозможно"
        (explanation: "чо" might be intentional slang — keep as-is)
      EXAMPLES
    end
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
