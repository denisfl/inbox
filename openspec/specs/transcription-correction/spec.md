# transcription-correction Specification

## Purpose
TBD - created by archiving change transcription-accuracy. Update Purpose after archive.
## Requirements
### Requirement: LLM corrects Whisper transcription output
After Whisper produces a transcription, the system SHALL pass the raw text through an LLM correction step before saving the final transcription block.

#### Scenario: LLM corrects obvious recognition errors
- **GIVEN** Whisper returns a transcription with a phonetic error (e.g., "житон")
- **WHEN** the LLM correction step processes it
- **THEN** the corrected text SHALL fix the obvious error (e.g., "жетон")
- **AND** the document title and text block SHALL use the corrected text

#### Scenario: LLM preserves accurate transcription unchanged
- **GIVEN** Whisper returns an accurate transcription with no obvious errors
- **WHEN** the LLM correction step processes it
- **THEN** the output SHALL be identical or trivially equivalent to the input (no rephrasing)

#### Scenario: Correction step uses focused prompt
- **WHEN** the correction API is called
- **THEN** the prompt SHALL explicitly instruct the LLM to fix only recognition errors, not rephrase or summarize

### Requirement: Raw Whisper output is preserved
The original Whisper transcription SHALL be stored alongside the corrected text for reference.

#### Scenario: Block content contains both raw and corrected text
- **WHEN** a voice transcription is saved
- **THEN** the text block's content JSON SHALL contain `"text"` (corrected) and `"raw_text"` (original Whisper output)

### Requirement: Correction step fails gracefully
If the Ollama API is unavailable or returns an error, the system SHALL NOT fail the transcription job.

#### Scenario: Ollama unavailable — fallback to raw text
- **GIVEN** the Ollama service is down or returns a non-200 response
- **WHEN** `TranscribeAudioJob` attempts the correction step
- **THEN** the job SHALL log the error and use the raw Whisper text as the final transcription
- **AND** the document SHALL be saved with the raw transcription (not lost)

#### Scenario: Correction timeout — fallback to raw text
- **GIVEN** Ollama takes longer than the timeout (60s)
- **WHEN** the correction step times out
- **THEN** the job SHALL rescue the timeout, log it, and proceed with raw text

### Requirement: Correction model is configurable
The Ollama model used for correction SHALL be configurable via environment variable.

#### Scenario: Default model
- **WHEN** `OLLAMA_CORRECTION_MODEL` is not set
- **THEN** the system SHALL use `llama3.2` as the default model

#### Scenario: Custom model via ENV
- **WHEN** `OLLAMA_CORRECTION_MODEL=mistral` is set
- **THEN** the system SHALL use `mistral` for the correction step

