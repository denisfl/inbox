## 1. TranscribeAudioJob — LLM Correction Step ✅ DONE

- [x] 1.1 After Whisper response, call `correct_transcription(raw_transcription, detected_language)` — returns corrected text or raw on error
- [x] 1.2 Implemented `correct_transcription(raw_text, detected_language = nil)` with:
  - Model: `gemma3:4b` (configurable via `OLLAMA_CORRECTION_MODEL` ENV)
  - Language-aware prompt: Russian by default/priority; English when `detected_language == 'en'`
  - `correction_examples(detected_language)` provides language-specific few-shot examples
  - Strict rules preventing over-correction; 60s timeout; graceful fallback to raw text
- [x] 1.3 `raw_transcription = data['text']` → `correct_transcription(raw_transcription, detected_language)` → `transcription`
- [x] 1.4 Block content stores all three fields:
  ```json
  { "text": "<corrected>", "raw_text": "<whisper original>", "language": "ru" }
  ```

## 2. Environment Configuration ✅ DONE

- [x] 2.1 `OLLAMA_CORRECTION_MODEL` added to `docker-compose.production.yml` (commented out, default `gemma3:4b`)
- [x] 2.2 `OLLAMA_BASE_URL=http://ollama:11434` already set in production

## 3. Ollama Model ✅ DONE

- [x] 3.1 Pull `gemma3:4b` on RPi: `docker compose exec ollama ollama pull gemma3:4b`
- [x] 3.2 Verify: `docker compose exec ollama ollama list`

## 4. Verification ✅ DONE

- [x] 4.1 Send a voice note via Telegram → check block content in Rails console:
  ```ruby
  Document.last.blocks.where(block_type: 'text').first.content_hash
  # expect: { "text" => "...", "raw_text" => "...", "language" => "ru" }
  ```
- [x] 4.2 Verify corrected ≠ raw only when there is an obvious error; otherwise identical
- [x] 4.3 Stop Ollama → send voice note → document still saved with raw text (warning logged)
