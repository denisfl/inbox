## 1. Database Migration

- [ ] 1.1 Generate migration:
  ```bash
  rails generate migration AddDocumentTypeToDocuments document_type:string
  ```
- [ ] 1.2 Set default value in migration: `default: 'note'`
- [ ] 1.3 Run migration locally; run on RPi after deploy

## 2. IntentClassifierService

- [ ] 2.1 Create `app/services/intent_classifier_service.rb` with:
  - `Result` struct: `intent`, `confidence`, `title`, `due_at`, `body`
  - `CONFIDENCE_THRESHOLD = 0.65`
  - `classify(text)` → calls Ollama `gemma3:4b` with structured JSON prompt
  - Prompt injects today's date for relative date resolution
  - Validates `intent` is in `['todo', 'event', 'note']`
  - Falls back to `note` on any error, low confidence, or unknown intent
  - Private: `call_ollama(text)`, `parse_due_at(value)`
- [ ] 2.2 Add `OLLAMA_INTENT_MODEL` ENV var (default: `gemma3:4b`) to `docker-compose.production.yml`

## 3. IntentRouter

- [ ] 3.1 Create `app/services/intent_router.rb` with:
  - `dispatch(result, telegram_chat_id)` — routes by `result.intent`
  - `create_todo(result, chat_id)` — creates Document(type=todo) + Block(kind=todo) + Tag('todo')
  - `create_event(result, chat_id)` — creates CalendarEvent; fallback to note on error
  - `create_note(result, chat_id)` — existing behavior: Document + text Block
  - `reply(chat_id, text)` — sends Telegram message
  - Confirmation messages:
    - todo: `"✅ Задача добавлена: #{title}"`
    - event: `"📅 Событие сохранено: #{title} на #{time_str}"`
    - note: `"📝 Заметка сохранена"`

## 4. Wire into TelegramMessageHandler

- [ ] 4.1 Read `app/services/telegram_message_handler.rb`
- [ ] 4.2 Replace direct document/block creation in `handle_text` with:
  ```ruby
  result = IntentClassifierService.classify(text)
  IntentRouter.dispatch(result, chat_id)
  ```
- [ ] 4.3 Remove old direct Telegram reply from `handle_text` (now sent by `IntentRouter`)

## 5. Wire into TranscribeAudioJob

- [ ] 5.1 Read `app/jobs/transcribe_audio_job.rb`
- [ ] 5.2 After `corrected_text = correct_transcription(raw_text, detected_language)`, replace raw block save with:
  ```ruby
  result = IntentClassifierService.classify(corrected_text)
  IntentRouter.dispatch(result, telegram_chat_id)
  ```
- [ ] 5.3 Ensure `telegram_chat_id` is passed through to the job (check current job args)

## 6. Document Model

- [ ] 6.1 Add `document_type` to `Document` model; optional enum:
  ```ruby
  # app/models/document.rb
  DOCUMENT_TYPES = %w[note todo].freeze
  ```

## 7. ENV Variables (docker-compose.production.yml)

- [ ] 7.1 Add to `web` and `worker` environments:
  ```yaml
  # - OLLAMA_INTENT_MODEL=gemma3:4b   # default, uncomment to override
  ```

## 8. Verification

- [ ] 8.1 Send "купить хлеб" in Telegram → confirm `Document.last.document_type == 'todo'`
- [ ] 8.2 Send "встреча завтра в 10" → confirm `CalendarEvent.last` exists with correct `start_at`
- [ ] 8.3 Send "интересная мысль про архитектуру" → confirm `Document.last.document_type == 'note'`
- [ ] 8.4 Send voice note with todo content → confirm todo created after transcription
- [ ] 8.5 Confirm Telegram replies arrive for all 3 intents
- [ ] 8.6 Kill Ollama → confirm all inputs still create a note (fallback works)
