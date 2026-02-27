## MODIFIED Requirements

### Requirement: Whisper uses automatic language detection by default
The Whisper transcription call SHALL NOT hardcode `language: 'ru'`. Language SHALL be auto-detected by Whisper unless overridden by `WHISPER_LANGUAGE` environment variable.

#### Scenario: English voice note transcribed correctly
- **GIVEN** the user sends an English voice note via Telegram
- **WHEN** `TranscribeAudioJob` processes the audio
- **THEN** Whisper SHALL auto-detect English and return correct English transcription
- **AND** the text block SHALL contain the English transcription text

#### Scenario: Russian voice note still transcribed correctly
- **GIVEN** the user sends a Russian voice note
- **WHEN** `TranscribeAudioJob` processes the audio
- **THEN** Whisper SHALL auto-detect Russian and transcription SHALL be in Russian

#### Scenario: Mixed-language audio — primary language detected
- **GIVEN** the user sends audio containing both Russian and English phrases
- **WHEN** transcription runs
- **THEN** Whisper SHALL detect the dominant language and transcribe accordingly (best-effort)

### Requirement: Language override via environment variable
The system SHALL support forcing a specific Whisper language via `WHISPER_LANGUAGE` environment variable.

#### Scenario: WHISPER_LANGUAGE not set — auto-detect
- **WHEN** `WHISPER_LANGUAGE` is absent or empty
- **THEN** the Whisper API call SHALL omit the `language` parameter (or pass `nil`), enabling auto-detection

#### Scenario: WHISPER_LANGUAGE=ru — force Russian
- **WHEN** `WHISPER_LANGUAGE=ru`
- **THEN** the Whisper API call SHALL pass `language: 'ru'` (original behavior preserved)

#### Scenario: WHISPER_LANGUAGE=en — force English
- **WHEN** `WHISPER_LANGUAGE=en`
- **THEN** the Whisper API call SHALL pass `language: 'en'`

### Requirement: Detected language stored in block content
The language detected (or forced) by Whisper SHALL be stored in the text block's content JSON.

#### Scenario: Language field in block content
- **WHEN** transcription completes successfully
- **THEN** the text block content JSON SHALL include a `"language"` key with the ISO 639-1 language code (e.g., `"en"`, `"ru"`)
- **AND** the key SHALL be omitted if Whisper does not return a language in its response
