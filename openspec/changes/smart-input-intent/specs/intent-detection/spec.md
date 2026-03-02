# Spec: Intent Detection

## Feature

`IntentClassifierService` classifies free-form Russian/English text from Telegram (voice or typed) into one of three intents: `todo`, `event`, or `note`.

---

## Functional Requirements

### FR-1: Classification via LLM

- The service sends the user's text to Ollama `gemma3:4b` with a structured prompt
- The LLM must return valid JSON with fields: `intent`, `confidence`, `title`, `due_at`
- The service must validate and parse this JSON; any parse failure falls back to `note`

### FR-2: Supported Intents

| Intent  | Trigger examples                                                                |
| ------- | ------------------------------------------------------------------------------- |
| `todo`  | "need to buy milk", "купить хлеб", "не забыть позвонить врачу"                  |
| `event` | "встреча в пятницу в 15:00", "zoom call tomorrow 10am", "запись к врачу завтра" |
| `note`  | "хорошая идея для статьи", "rails tip: use strict_loading", "прочитал что..."   |

### FR-3: Confidence Threshold

- If `confidence < 0.65`, override intent to `note` regardless of LLM response
- Confidence must be a float `0.0..1.0`

### FR-4: Title Extraction

- LLM extracts a concise title from the input text
- Fallback title: `text.truncate(80)` if LLM returns blank title

### FR-5: Due Date Extraction

- For `event` intent, LLM extracts a datetime in ISO8601 format
- Prompt injects today's date to allow relative date resolution
- If date cannot be parsed, `due_at` is `nil`

### FR-6: Bilingual Support

- Works for Russian and English input without language switching
- Same prompt handles both; LLM picks up language from context

### FR-7: Error Resilience

- Ollama timeout: fallback to `note`, log at `ERROR`
- HTTP error from Ollama: fallback to `note`, log at `ERROR`
- Malformed JSON: fallback to `note`, log at `ERROR`
- All fallbacks return a valid `Result` struct (never raise to caller)

---

## Non-Functional Requirements

- Classification latency: < 5 seconds (Ollama local inference)
- No external API calls (fully local)
- No database writes (classification only; routing handled by `IntentRouter`)

---

## Input / Output Contract

**Input:** `String` — any text, 1 to ~1000 characters

**Output:** `IntentClassifierService::Result` struct:

```ruby
{
  intent:     String,   # 'todo' | 'event' | 'note'
  confidence: Float,    # 0.0..1.0
  title:      String,   # non-blank
  due_at:     DateTime | nil,
  body:       String    # original input text
}
```

---

## Test Cases

| Input                                 | Expected Intent | Notes                  |
| ------------------------------------- | --------------- | ---------------------- |
| "купить молоко и хлеб"                | `todo`          | RU shopping            |
| "не забыть позвонить маме"            | `todo`          | RU reminder            |
| "buy coffee beans"                    | `todo`          | EN shopping            |
| "встреча с Андреем в пятницу в 14:00" | `event`         | RU with time           |
| "zoom call tomorrow at 10am"          | `event`         | EN with relative date  |
| "запись к зубному завтра в 11"        | `event`         | RU medical appointment |
| "интересная идея для проекта"         | `note`          | RU generic idea        |
| "rails tip: use strict_loading"       | `note`          | EN tech note           |
| "" (empty)                            | `note`          | edge case              |
| Ollama connection refused             | `note`          | fallback               |
