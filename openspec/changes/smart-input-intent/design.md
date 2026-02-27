# Design: Smart Input Intent Detection

## Problem

All Telegram input (voice notes or text) currently creates a generic document with a `text` block. The user wants the system to automatically detect **what type of content** is being created — a to-do, a calendar event, or a note — and route it accordingly.

---

## Architecture

```
TelegramMessageHandler
  handle_text(text)
    → IntentClassifierService.classify(text)
    → IntentRouter.dispatch(intent_result, user)

TranscribeAudioJob
  (after correction)
    → IntentClassifierService.classify(corrected_text)
    → IntentRouter.dispatch(intent_result, user)
```

---

## IntentClassifierService

```ruby
# app/services/intent_classifier_service.rb
class IntentClassifierService
  Result = Struct.new(:intent, :confidence, :title, :due_at, :body, keyword_init: true)

  SUPPORTED_INTENTS = %w[todo event note]
  CONFIDENCE_THRESHOLD = 0.65

  def self.classify(text)
    new.classify(text)
  end

  def classify(text)
    response = call_ollama(text)
    parsed = JSON.parse(response)

    intent = parsed['intent'].to_s
    intent = 'note' unless SUPPORTED_INTENTS.include?(intent)

    confidence = parsed['confidence'].to_f
    intent = 'note' if confidence < CONFIDENCE_THRESHOLD

    Result.new(
      intent: intent,
      confidence: confidence,
      title: parsed['title'].to_s.presence || text.truncate(80),
      due_at: parse_due_at(parsed['due_at']),
      body: text
    )
  rescue StandardError => e
    Rails.logger.error("IntentClassifier failed: #{e.message}")
    Result.new(intent: 'note', confidence: 0.0, title: text.truncate(80), due_at: nil, body: text)
  end

  private

  def call_ollama(text)
    # POST to Ollama with structured JSON prompt
    # Returns JSON string
  end

  def parse_due_at(value)
    return nil if value.blank?
    Time.parse(value)
  rescue ArgumentError
    nil
  end
end
```

---

## LLM Prompt

```
You are an intent classifier for a personal inbox app. Given a user's note or voice transcription, classify it into one of these intents:
- "todo": user wants to do something ("need to", "buy", "call", "remind me", "не забыть", "купить", "позвонить", "сделать")
- "event": user is creating a time-bound activity ("meeting", "appointment", "на пятницу", "завтра в 10", "встреча", "созвон")
- "note": general information, ideas, references, anything else

Respond with ONLY valid JSON (no markdown, no explanation):
{
  "intent": "todo" | "event" | "note",
  "confidence": 0.0 to 1.0,
  "title": "concise title for the item",
  "due_at": "ISO8601 datetime or null"
}

If intent is "event" and a time is mentioned, extract it as ISO8601 datetime using today's date as reference (today = {DATE}).
If confidence is below 0.65, set intent to "note".

User input:
{TEXT}
```

---

## IntentRouter

```ruby
# app/services/intent_router.rb
class IntentRouter
  def self.dispatch(result, telegram_chat_id)
    new.dispatch(result, telegram_chat_id)
  end

  def dispatch(result, telegram_chat_id)
    case result.intent
    when 'todo'  then create_todo(result, telegram_chat_id)
    when 'event' then create_event(result, telegram_chat_id)
    else              create_note(result, telegram_chat_id)
    end
  end

  private

  def create_todo(result, telegram_chat_id)
    document = Document.create!(
      title: result.title,
      document_type: 'todo',
      source: 'telegram'
    )
    document.blocks.create!(kind: 'todo', content: { 'text' => result.body })
    tag = Tag.find_or_create_by!(name: 'todo')
    document.tags << tag unless document.tags.include?(tag)
    reply(telegram_chat_id, "✅ Задача добавлена: #{result.title}")
  end

  def create_event(result, telegram_chat_id)
    # If google-calendar story is live, create CalendarEvent
    # Otherwise create a document tagged #event
    event = CalendarEvent.create!(
      title: result.title,
      description: result.body,
      start_at: result.due_at || 1.day.from_now.noon,
      end_at: (result.due_at || 1.day.from_now.noon) + 1.hour,
      google_event_id: "local_#{SecureRandom.hex(8)}"
    )
    time_str = event.start_at.strftime('%d.%m %H:%M')
    reply(telegram_chat_id, "📅 Событие сохранено: #{result.title} на #{time_str}")
  rescue => e
    Rails.logger.warn("CalendarEvent creation failed: #{e.message}; falling back to note")
    create_note(result, telegram_chat_id)
  end

  def create_note(result, telegram_chat_id)
    document = Document.create!(
      title: result.title,
      document_type: 'note',
      source: 'telegram'
    )
    document.blocks.create!(kind: 'text', content: { 'text' => result.body })
    reply(telegram_chat_id, "📝 Заметка сохранена")
  end

  def reply(chat_id, text)
    bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
    bot.api.send_message(chat_id: chat_id, text: text)
  end
end
```

---

## Document Model Change

- Add `document_type` column (`string`, default: `'note'`): `'note' | 'todo'`
- The `source` column already exists (via telegram fields migration)

---

## Error Handling & Fallback

| Scenario | Behavior |
|----------|----------|
| Ollama unreachable | Fallback to `note`; log error |
| Malformed JSON response | Fallback to `note`; log error |
| Low confidence (`< 0.65`) | Classify as `note` |
| Unknown intent | Classify as `note` |
| `CalendarEvent` save fails | Fallback to `note`; log warning |

---

## Integration Points

| Modified File | Change |
|---------------|--------|
| `app/services/telegram_message_handler.rb` | Replace direct document creation with `IntentRouter.dispatch` |
| `app/jobs/transcribe_audio_job.rb` | After correction, call `IntentRouter.dispatch` instead of raw block save |
| `app/models/document.rb` | Add `document_type` field; optional enum |
| `db/migrate/` | New migration for `document_type` on `documents` |

---

## Language Support

- Prompt works for Russian and English inputs
- Date/time references understood in both languages: "в пятницу в 15:00", "next Friday at 3pm", "завтра утром"
- LLM resolves relative dates using `today = {DATE}` injected into prompt
- Time zone: use `Time.current` (Rails time zone, configured in `application.rb`)
