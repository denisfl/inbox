## Context

`TranscribeAudioJob` currently passes `language: 'ru'` hardcoded to the Whisper API. This forces Russian recognition even when the user speaks English or mixes languages. Whisper natively supports automatic language detection and 99 languages — the fix is to either remove the hardcoded language or make it configurable.

Telegram's `message.from.language_code` provides the user's Telegram UI language (e.g., `"en"`, `"ru"`) but does not indicate the spoken language of the audio. Therefore auto-detection is more reliable than using Telegram's language code.

## Goals / Non-Goals

**Goals:**
- Enable correct transcription of English voice notes
- Enable automatic language detection for all voice/audio messages
- Store the detected language in the block metadata
- Display detected language in the UI (optional, minimal)

**Non-Goals:**
- Per-message language selection by the user (no commands or captions)
- Translation of transcribed text
- Supporting languages beyond what Whisper already supports
- Re-transcribing old documents

## Decisions

### Decision: Remove hardcoded `language: 'ru'` — use auto-detection

**Chosen:** Omit the `language` parameter from the Whisper API call (or pass `language: nil`). Whisper's default behavior is automatic language detection.

**Rationale:**
- Simplest possible change — one line removed
- Whisper's auto-detection is accurate for distinct languages (Russian, English)
- No user-facing complexity

**Alternative considered:** Allow user to send `/lang en` command to set preference — rejected as over-engineering for a personal tool.

### Decision: Make language configurable via ENV as override

Add `WHISPER_LANGUAGE` ENV var. If set, it overrides auto-detection. Useful for users who exclusively speak one language and want slightly better accuracy.

**Behavior:**
- `WHISPER_LANGUAGE` not set → Whisper auto-detects (recommended)
- `WHISPER_LANGUAGE=ru` → force Russian (original behavior)
- `WHISPER_LANGUAGE=en` → force English

### Decision: Store detected language in text block content

Whisper's API response includes a `language` field. Store it in the text block's content JSON:
```json
{ "text": "...", "raw_text": "...", "language": "en" }
```

(Note: if `transcription-accuracy` story is also implemented, `raw_text` already exists; `language` is simply added alongside.)

## Risks / Trade-offs

- **Risk:** Auto-detection less accurate than explicit language for very short clips → **Mitigation:** Acceptable trade-off for a personal tool; user can set `WHISPER_LANGUAGE=ru` if needed.
- **Risk:** Whisper service (`whisper_service/app.py`) may not return `language` in the response → **Mitigation:** Check response; store only if present; fail gracefully.
