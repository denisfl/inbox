## Context

Whisper transcribes Russian speech with good recall but poor precision on proper nouns, domain-specific terms, and short phonetically similar words. Examples: "в лада" → "Влада" (a name), "житон" → "жетон" (token/chip). The resulting text can be confusing or misleading.

The system already has Ollama running as a Docker service (accessible at `http://ollama:11434`). A lightweight LLM post-processing step can correct transcription errors by understanding context.

## Goals / Non-Goals

**Goals:**
- Run LLM correction pass on Whisper output before saving the transcription text block
- Improve word-level accuracy for proper nouns, names, and domain terms
- Store the original (raw) Whisper output for debugging/reference
- Keep the correction step async and non-blocking (stays inside the existing `TranscribeAudioJob`)

**Non-Goals:**
- Full semantic rewriting or summarization
- Replacing Whisper — Whisper remains the primary ASR
- UI for reviewing/comparing raw vs corrected text
- Real-time streaming correction

## Decisions

### Decision: LLM correction via Ollama after Whisper

**Chosen:** Call `http://ollama:11434/api/generate` (or `/api/chat`) with a focused correction prompt after getting Whisper output, before saving the text block.

**Rationale:**
- Ollama is already in the stack (same Docker network)
- No new services or costs
- Prompt can be tuned to preserve structure and only fix obvious errors

**Prompt strategy:**
```
You are a Russian transcription corrector. Fix only obvious speech recognition errors 
(wrong words, merged/split words, wrong proper nouns). Do not rephrase or summarize. 
Return only the corrected text, nothing else.

Original transcription: "{whisper_output}"
```

### Decision: Store raw transcription in block metadata

The raw Whisper output is stored in the block's `content` JSON as `raw_text`, while the LLM-corrected output goes in `text`. This allows future comparison and rollback without re-transcription.

**Block content JSON:**
```json
{
  "text": "<LLM corrected>",
  "raw_text": "<Whisper original>"
}
```

### Decision: Graceful fallback if Ollama is unavailable

If the Ollama API call fails (timeout, service down, model not loaded), log the error and proceed with the raw Whisper transcription. Correction is best-effort — transcription must not fail because of a correction error.

### Decision: Ollama model

Use `llama3.2` (already pulled, lightweight). Can be made configurable via `OLLAMA_CORRECTION_MODEL` ENV var.

## Risks / Trade-offs

- **Risk:** LLM overcorrects or changes meaning → **Mitigation:** Focused prompt with explicit "fix only obvious errors" instruction; raw text preserved for reference.
- **Risk:** Ollama adds latency to transcription job → **Mitigation:** Job is already async; added latency is acceptable. Timeout set to 60s for correction step.
- **Risk:** Ollama not running or model not pulled → **Mitigation:** Graceful fallback to raw text.
- **Risk:** Token usage for long transcriptions → **Trade-off:** Acceptable for personal use; llama3.2 handles typical voice note lengths well.
