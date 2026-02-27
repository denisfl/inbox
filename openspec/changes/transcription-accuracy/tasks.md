## 1. TranscribeAudioJob — LLM Correction Step

- [ ] 1.1 After receiving `transcription = data['text']` from Whisper, call a new private method `correct_transcription(transcription)` that returns the LLM-corrected text (or the original on error)
- [ ] 1.2 Implement `correct_transcription(raw_text)`:
  ```ruby
  def correct_transcription(raw_text)
    model = ENV.fetch('OLLAMA_CORRECTION_MODEL', 'llama3.2')
    prompt = <<~PROMPT
      You are a Russian transcription corrector. Fix only obvious speech recognition errors
      (wrong words, merged/split words, incorrect proper nouns). Do not rephrase or summarize.
      Return only the corrected text, nothing else.

      Original transcription: "#{raw_text}"
    PROMPT

    response = HTTP.timeout(60).post(
      "#{ENV.fetch('OLLAMA_BASE_URL', 'http://ollama:11434')}/api/generate",
      json: { model: model, prompt: prompt, stream: false }
    )

    unless response.status.success?
      Rails.logger.warn("Ollama correction failed: #{response.status}")
      return raw_text
    end

    data = JSON.parse(response.body)
    data['response']&.strip.presence || raw_text
  rescue StandardError => e
    Rails.logger.warn("Transcription correction error (using raw): #{e.message}")
    raw_text
  end
  ```
- [ ] 1.3 Replace the existing `transcription` variable usage so the text block uses corrected text:
  ```ruby
  raw_transcription = data['text']
  transcription = correct_transcription(raw_transcription)
  ```
- [ ] 1.4 Store both in the text block content:
  ```ruby
  document.blocks.create!(
    block_type: 'text',
    position: 0,
    content: { text: transcription, raw_text: raw_transcription }.to_json
  )
  ```

## 2. Environment Configuration

- [ ] 2.1 Add `OLLAMA_CORRECTION_MODEL` to `docker-compose.production.yml` environment (optional, defaults to `llama3.2`)
- [ ] 2.2 Ensure `OLLAMA_BASE_URL` is set in production (should already be `http://ollama:11434`)

## 3. Ollama Model

- [ ] 3.1 Verify `llama3.2` is pulled in Ollama: `docker exec -it <ollama_container> ollama list`
- [ ] 3.2 If not pulled: `docker exec -it <ollama_container> ollama pull llama3.2`

## 4. Verification

- [ ] 4.1 Send a voice note via Telegram with a word known to be misrecognized (e.g., say "жетон")
- [ ] 4.2 Check document block content in the web UI or via Rails console:
  ```ruby
  Document.last.blocks.first.content_hash
  # Should have: { "text" => "...", "raw_text" => "..." }
  ```
- [ ] 4.3 Test Ollama unavailable: temporarily stop Ollama container → send voice note → verify document still saved with raw text
- [ ] 4.4 Check Rails logs for `Transcription correction error` warning when Ollama is down
