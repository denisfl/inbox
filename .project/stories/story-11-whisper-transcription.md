# Story 11: Whisper Audio Transcription

**Priority:** P0 (Critical)  
**Complexity:** Very High  
**Estimated Effort:** 4-5 days  
**Dependencies:** Story 10 (Telegram Bot)  
**Status:** Blocked

---

## User Story

As a user, I want voice messages transcribed automatically so that I can capture audio notes.

---

## Acceptance Criteria

### ✅ Whisper Service Setup

- [ ] Whisper Docker service configured
- [ ] Model: **base** (1.5GB, Russian language)
- [ ] Python service exposing HTTP API
- [ ] Environment variables:
  ```bash
  WHISPER_MODEL_SIZE=base
  WHISPER_LANGUAGE=ru
  WHISPER_TIMEOUT=300  # 5 minutes max
  ```

### ✅ Transcription Job (Sidekiq)

- [ ] Job: `TranscribeAudioJob`
- [ ] Queue: `default`
- [ ] Retry: 3 attempts with exponential backoff
- [ ] Timeout: 5 minutes
- [ ] Input: Document ID + audio file
- [ ] Output: Update document with transcription

### ✅ Transcription Flow

**1. Receive Voice Message (Telegram)**

- [ ] Download .ogg file from Telegram
- [ ] Create Document with placeholder:
  ```ruby
  {
    title: "🎤 Voice note",
    blocks: [
      { type: 'TextBlock', data: { text: "🎤 Transcribing..." } }
    ]
  }
  ```
- [ ] Queue `TranscribeAudioJob`
- [ ] Reply to user: "🎤 Transcribing your voice note..."

**2. Background Transcription**

- [ ] Convert .ogg to .wav (if needed)
- [ ] Call Whisper API: `POST /transcribe`
- [ ] Parse response (text + timestamps)
- [ ] Update document blocks:
  ```ruby
  [
    { type: 'TextBlock', data: { text: transcription } },
    { type: 'FileBlock', data: { filename: 'voice.ogg' } }
  ]
  ```

**3. Notify User**

- [ ] Send Telegram message: "✅ Transcription complete: <preview>"
- [ ] Include link to document (if web URL available)

### ✅ Whisper HTTP API

**Python Service:**

```python
# whisper_service/app.py
from flask import Flask, request, jsonify
import whisper
import os

app = Flask(__name__)
model = whisper.load_model(os.getenv('WHISPER_MODEL_SIZE', 'base'))

@app.route('/transcribe', methods=['POST'])
def transcribe():
    audio_file = request.files['audio']
    language = request.form.get('language', 'ru')

    result = model.transcribe(
        audio_file,
        language=language,
        fp16=False  # CPU mode for RPi
    )

    return jsonify({
        'text': result['text'],
        'segments': result['segments']
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

**Dockerfile:**

```dockerfile
FROM python:3.11-slim

RUN pip install openai-whisper flask

COPY app.py /app/
WORKDIR /app

CMD ["python", "app.py"]
```

### ✅ Rails Integration

**Sidekiq Job:**

```ruby
# app/jobs/transcribe_audio_job.rb
class TranscribeAudioJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(document_id, audio_path)
    document = Document.find(document_id)

    # Call Whisper API
    response = HTTP.timeout(300).post(
      "#{ENV['WHISPER_BASE_URL']}/transcribe",
      form: {
        audio: HTTP::FormData::File.new(audio_path),
        language: 'ru'
      }
    )

    data = JSON.parse(response.body)
    transcription = data['text']

    # Update document
    document.blocks.destroy_all
    document.blocks.create!([
      {
        type: 'TextBlock',
        position: 0,
        data: { text: transcription }
      },
      {
        type: 'FileBlock',
        position: 1,
        data: { filename: 'voice.ogg' }
      }
    ])

    document.update!(title: transcription.truncate(50))

    # Notify user via Telegram
    TelegramNotifier.notify(
      document.telegram_chat_id,
      "✅ Transcription complete: #{transcription.truncate(100)}"
    )
  rescue => e
    Rails.logger.error("Transcription failed: #{e.message}")
    document.blocks.first.update!(data: { text: "❌ Transcription failed" })
  end
end
```

### ✅ Error Handling

- [ ] Timeout (>5 min) → Update: "❌ Transcription timeout"
- [ ] Unsupported format → Convert to .wav first
- [ ] Empty transcription → "❌ No speech detected"
- [ ] Service unavailable → Retry with backoff
- [ ] File too large (>20MB) → "❌ File too large"

### ✅ Testing

- [ ] RSpec tests for `TranscribeAudioJob`:
  - Successful transcription
  - Timeout handling
  - API errors
  - Empty audio
- [ ] Mock Whisper API responses
- [ ] Test audio file fixtures
- [ ] Code coverage: 80%+

### ✅ Performance

**Expected Performance (RPi 5, base model):**

- 1 minute audio → 1-2 minutes transcription
- Memory usage: ~2GB during transcription
- CPU: 50-70%
- Only one transcription at a time (Sidekiq concurrency: 1 for this queue)

---

## Technical Tasks

1. **Create Whisper Service**

   ```bash
   mkdir whisper_service
   cd whisper_service
   # Create Dockerfile and app.py
   ```

2. **Add to docker-compose.yml**

   ```yaml
   whisper:
     build: ./whisper_service
     environment:
       - WHISPER_MODEL_SIZE=base
     volumes:
       - ./tmp/audio:/tmp/audio
     ports:
       - "5000:5000"
   ```

3. **Create Sidekiq Job**

   ```bash
   rails g job TranscribeAudio
   ```

4. **Update TelegramMessageHandler**
   - Queue job on voice message
   - Store chat_id for notification

5. **Write Tests**
   ```bash
   rspec spec/jobs/transcribe_audio_job_spec.rb
   ```

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Whisper service running in Docker
- [ ] Transcription job working
- [ ] Tests passing (80%+ coverage)
- [ ] User receives transcription via Telegram
- [ ] Performance acceptable (<2 min per minute)
- [ ] Error handling robust
- [ ] Documentation updated

---

## Notes

- **Critical**: Only one transcription at a time (memory intensive)
- Use separate Sidekiq queue: `transcription` with concurrency: 1
- Store audio files temporarily, clean up after transcription
- Consider fallback to `small` model if `base` too slow
- Russian language accuracy: 90%+ for clear audio
