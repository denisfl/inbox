## Why

Currently every Telegram message (text or voice) is saved as a plain document/note. The user's natural language input often implies a specific intent — "reminder to buy milk tomorrow", "meeting with Vlada on Friday at 3pm", "idea: refactor auth module". Without intent detection, all of this ends up as undifferentiated notes.

Detecting intent at input time allows Inbox to automatically create the right kind of record: a to-do task, a calendar event, or a plain note — giving the user a true smart inbox.

## What Changes

- After receiving a text or transcribed voice message, run an LLM intent classification step (via Ollama) before saving
- Based on detected intent, route the content to the appropriate handler:
  - **todo** → create a document with `source: 'todo'`, tagged `#todo`, with a checkbox block
  - **event** → extract date/time and title; create a `CalendarEvent` (or Google Calendar entry if calendar story is implemented)
  - **note** → existing behavior (plain document)
- Confidence threshold: if intent is ambiguous, fall back to plain note
- Telegram reply confirms the detected intent: "✅ To-do added", "📅 Event saved for Friday 15:00", "📝 Note saved"

## Capabilities

### New Capabilities

- `intent-detection`: LLM (Ollama `gemma3:4b`) classifies incoming text into `todo`, `event`, or `note`. Returns structured JSON with intent, title, due date (for events/todos), and confidence score.
- `todo-creation`: When intent is `todo`, creates a document with a `todo` block type containing the task text and completion checkbox. Tagged `#todo`.
- `event-from-text`: When intent is `event`, extracts datetime and summary, creates a `CalendarEvent` record (or queues Google Calendar creation if calendar story is live).

### Modified Capabilities

- `text-handling` in `TelegramMessageHandler#handle_text`: delegates to `IntentRouter` service after LLM classification
- `transcription` in `TranscribeAudioJob`: after transcription, runs intent classification on the result (same `IntentRouter`)

### New Components

- `IntentClassifierService` — calls Ollama with structured prompt; returns `{ intent:, confidence:, title:, due_at: }`
- `IntentRouter` — dispatches to the right document/event creator based on classified intent
- `config/recurring.yml` — no changes needed (intent runs inline per message)

## Impact

- **Code**: `TelegramMessageHandler` (text path + document path after voice), `TranscribeAudioJob` (post-transcription routing)
- **Model**: Documents gain `document_type` field (`note`, `todo`, `event`) — migration needed
- **Ollama**: additional LLM call per message (fast: classification only, no generation) — best-effort, falls back to `note` on error
- **No new infrastructure**
- **Language**: must work for both Russian and English inputs (prompt written to handle both)
