## 1. TranscribeAudioJob — Remove Hardcoded Language

- [ ] 1.1 In `app/jobs/transcribe_audio_job.rb`, replace:
  ```ruby
  form: {
    audio: HTTP::FormData::File.new(temp_file.path),
    language: 'ru'
  }
  ```
  With:
  ```ruby
  whisper_language = ENV['WHISPER_LANGUAGE'].presence
  form_data = { audio: HTTP::FormData::File.new(temp_file.path) }
  form_data[:language] = whisper_language if whisper_language.present?

  response = HTTP.timeout(300).post(
    "#{ENV.fetch('WHISPER_BASE_URL', 'http://whisper:5000')}/transcribe",
    form: form_data
  )
  ```

## 2. Store Detected Language in Block Content

- [ ] 2.1 After parsing Whisper response, extract detected language:
  ```ruby
  transcription = data['text']
  detected_language = data['language'] # may be nil if Whisper doesn't return it
  ```
- [ ] 2.2 Include `language` in the text block content JSON (alongside `text` and optionally `raw_text` from transcription-accuracy story):
  ```ruby
  block_content = { text: transcription }
  block_content[:raw_text] = raw_transcription if raw_transcription.present?
  block_content[:language] = detected_language if detected_language.present?

  document.blocks.create!(
    block_type: 'text',
    position: 0,
    content: block_content.to_json
  )
  ```

## 3. Whisper Service — Verify Language in Response

- [ ] 3.1 Check `whisper_service/app.py` — verify that the `/transcribe` endpoint returns `language` in its JSON response (Whisper's `transcribe()` result includes `language`)
- [ ] 3.2 If `language` is not returned, add it to the Flask response: `return jsonify({"text": result["text"], "language": result.get("language", "")})`

## 4. Environment Configuration

- [ ] 4.1 Document `WHISPER_LANGUAGE` in `docker-compose.production.yml` as an optional env var (commented out by default):
  ```yaml
  # - WHISPER_LANGUAGE=ru  # Uncomment to force language; omit for auto-detection
  ```

## 5. Verification

- [ ] 5.1 Send an English voice note via Telegram → check document block content for English text and `"language": "en"`
- [ ] 5.2 Send a Russian voice note → verify Russian transcription still works correctly
- [ ] 5.3 Set `WHISPER_LANGUAGE=ru` → send English voice note → verify it transcribes (possibly incorrectly) in Russian mode
- [ ] 5.4 Check `whisper_service` logs for detected language output
