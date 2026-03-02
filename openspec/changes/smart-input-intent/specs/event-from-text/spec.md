# Spec: Event Creation from Text

## Feature

When `IntentClassifierService` returns `intent: 'event'`, `IntentRouter` creates a `CalendarEvent` record with the extracted time and confirms via Telegram. If `CalendarEvent` creation fails (e.g., google-calendar story not yet deployed), falls back to note.

---

## Functional Requirements

### FR-1: CalendarEvent Creation

- Create a `CalendarEvent` with:
  - `title`: from `Result#title`
  - `description`: `result.body` (full original text)
  - `start_at`: `result.due_at` if present; otherwise `1.day.from_now.noon`
  - `end_at`: `start_at + 1.hour`
  - `google_event_id`: `"local_<SecureRandom.hex(8)>"` (local-only marker)

### FR-2: Telegram Confirmation

- Send confirmation with extracted time:
  ```
  📅 Событие сохранено: <title> на <DD.MM HH:MM>
  ```
- If `due_at` was nil (no time extracted), still confirm with the default time

### FR-3: Fallback to Note

- If `CalendarEvent` save fails for any reason, log at `WARN` and call `create_note` instead
- User receives note confirmation; no error shown

### FR-4: Date/Time Extraction

- The LLM extracts relative dates using today's date injected into prompt
- Examples that must resolve correctly:
  - "в пятницу в 15:00" → next Friday 15:00
  - "завтра в 10 утра" → tomorrow 10:00
  - "next Monday at 2pm" → next Monday 14:00
- If the extracted `due_at` is in the past (e.g., "вчера"), treat it as `nil` → use default

### FR-5: Integration with google-calendar Story

- If `google-calendar` story is live, the locally-created `CalendarEvent` will be pushed to Google Calendar on next sync (out of scope of this story — one-way for now)
- The `google_event_id: "local_*"` prefix distinguishes local-only events from synced ones

---

## Non-Functional Requirements

- Must not block Telegram handler — all DB and API calls within `IntentRouter` which is called from a background job (`TranscribeAudioJob`) or inline from `TelegramMessageHandler`
- Fallback must always succeed; never leave user without a response

---

## Error Handling

| Scenario                               | Behavior                                                  |
| -------------------------------------- | --------------------------------------------------------- |
| `CalendarEvent` table not yet migrated | Rescue `ActiveRecord::StatementInvalid`; fallback to note |
| `due_at` in the past                   | Use default `1.day.from_now.noon`                         |
| LLM returns `due_at: null`             | Use default time; confirm with it                         |
| Telegram send fails                    | Log at `WARN`; event is saved                             |

---

## Verification

- Input "встреча с командой в пятницу в 15:00" → `CalendarEvent.last.title == "встреча с командой"`
- Confirm `CalendarEvent.last.start_at` is next Friday at 15:00
- Confirm Telegram reply: "📅 Событие сохранено: ..."
- Input with no time → `CalendarEvent.last.start_at` is tomorrow noon
- Input causing save error → document created with `document_type: 'note'`
