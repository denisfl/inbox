# Spec: Todo Creation

## Feature

When `IntentClassifierService` returns `intent: 'todo'`, `IntentRouter` creates a structured to-do document and confirms via Telegram reply.

---

## Functional Requirements

### FR-1: Document Creation
- Create a `Document` with:
  - `title`: from `Result#title`
  - `document_type`: `'todo'`
  - `source`: `'telegram'`

### FR-2: Block Creation
- Create one `Block` with:
  - `kind`: `'todo'`
  - `content`: `{ 'text' => result.body }`
  - Linked to the document above

### FR-3: Auto-Tagging
- Find or create `Tag` with `name: 'todo'`
- Add it to the document's tags (no duplicate tags)

### FR-4: Telegram Confirmation
- Send a confirmation message to the originating chat:
  ```
  ✅ Задача добавлена: <title>
  ```

### FR-5: Entry Points
- Triggered from `TelegramMessageHandler#handle_text` (typed text)
- Triggered from `TranscribeAudioJob` (voice note after transcription)
- Both paths call `IntentRouter.dispatch(result, telegram_chat_id)`

---

## Non-Functional Requirements

- Must be atomic: if document save fails, do not send Telegram confirmation
- Must not raise exceptions to caller — log and fail silently on Telegram send errors

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| `Document.create!` fails (validation) | Raise — let caller handle; do not confirm |
| `Block.create!` fails | Raise — document is orphaned; log at `ERROR` |
| Telegram send fails | Log at `WARN`; document already saved; no retry |

---

## Verification

- Confirm `Document.last.document_type == 'todo'` after input "купить хлеб"
- Confirm `Document.last.tags.map(&:name).include?('todo')`
- Confirm `Document.last.blocks.first.kind == 'todo'`
- Confirm Telegram reply received in bot chat
