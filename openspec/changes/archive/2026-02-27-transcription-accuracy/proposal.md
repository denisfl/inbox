## Why

Voice transcriptions sometimes produce phonetically similar but contextually wrong words ("в лада" instead of "Влада", "житон" instead of "жетон"). Post-processing with an LLM (Ollama) can fix these errors using context, improving note quality.

## What Changes

- After Whisper transcription, call Ollama API to proofread and correct the text
- Prompt: fix spelling/grammar errors, proper nouns, and contextually wrong words while preserving the original meaning
- Store original Whisper output + corrected text separately (for audit)
- Configurable: can be enabled/disabled via ENV

## Capabilities

### New Capabilities
- `transcription-correction`: After Whisper produces a raw transcript, an LLM correction pass (Ollama) fixes contextual errors (proper nouns, phonetically similar words, punctuation). Original transcript is preserved in metadata.

### Modified Capabilities
- `transcription`: The `TranscribeAudioJob` pipeline gains an additional LLM correction step after Whisper output.

## Impact

- **Code**: `TranscribeAudioJob` — add LLM correction step; new `OllamaService` or inline Ollama API call; `Block` model — store original transcript in metadata
- **Dependencies**: Ollama already deployed (mistral model)
- **Latency**: adds ~2-5s per voice message (LLM inference on RPi)
- **ENV**: `TRANSCRIPTION_CORRECTION_ENABLED=true` (optional toggle)
