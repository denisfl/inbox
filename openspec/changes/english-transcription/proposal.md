## Why

Whisper currently only transcribes Russian (`language: 'ru'`). Users may send voice messages in English or switch between languages. Whisper supports automatic language detection and 99 languages — we should enable this.

## What Changes

- Change Whisper API call from `language: 'ru'` to automatic detection (omit language parameter or use `language: nil`)
- Optionally: detect language from user preference or Telegram user language code
- Display detected language in document metadata

## Capabilities

### New Capabilities
- `multilingual-transcription`: Whisper automatically detects the spoken language. Detected language is stored in document/block metadata and displayed in the UI.

### Modified Capabilities
- `transcription`: `TranscribeAudioJob` no longer hardcodes `language: 'ru'`; uses automatic detection or user preference.

## Impact

- **Code**: `TranscribeAudioJob` — remove hardcoded `language: 'ru'`; parse `language` from Whisper response; store in block metadata
- **Model**: `Block` metadata field — add `language` key
- **Whisper service**: already supports language detection (no change needed)
- **No new dependencies**
- **Accuracy trade-off**: auto-detection is slightly less accurate for short clips vs explicit language
