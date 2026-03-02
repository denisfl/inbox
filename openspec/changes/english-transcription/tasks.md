## 1. TranscribeAudioJob — Remove Hardcoded Language ✅ DONE

- [x] 1.1 Removed `language: 'ru'`; replaced with `WHISPER_LANGUAGE` ENV override + auto-detection:
  ```ruby
  whisper_language = ENV['WHISPER_LANGUAGE'].presence
  form_data = { audio: HTTP::FormData::File.new(temp_file.path) }
  form_data[:language] = whisper_language if whisper_language
  ```

## 2. Store Detected Language in Block Content ✅ DONE

- [x] 2.1 `detected_language = data['language'].presence` extracted from Whisper response
- [x] 2.2 Included in text block content JSON:
  ```json
  { "text": "...", "raw_text": "...", "language": "en" }
  ```
- [x] 2.3 `detected_language` passed to `correct_transcription` — LLM prompt adapts per language (Russian priority)

## 3. Whisper Service — Verify Language in Response ✅ DONE

- [x] 3.1 `whisper_service/app.py` already returns `language` in response (`info.language` from faster-whisper). No changes needed.

## 4. Environment Configuration ✅ DONE

- [x] 4.1 `WHISPER_LANGUAGE` added to `docker-compose.production.yml` as commented-out optional override:
  ```yaml
  # - WHISPER_LANGUAGE=ru  # force language; omit for auto-detection
  ```

## 5. Verification

- [ ] 5.1 Send an English voice note → check block content: `"language": "en"`, text in English
- [ ] 5.2 Send a Russian voice note → `"language": "ru"`, text in Russian
- [ ] 5.3 Set `WHISPER_LANGUAGE=ru` → English audio → forced Russian transcription mode
