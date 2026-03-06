---
id: audio-recording
artifact: tasks
---

## Tasks

### Phase 1: Backend -- Upload endpoint triggers transcription

- [x] **T1.1** In `Api::DocumentsController#upload`, after creating a file block, detect audio content type and enqueue `TranscribeAudioJob.perform_later(block.document_id, block.file.blob.key)`
- [x] **T1.2** Add `is_audio` flag to the JSON response so frontend knows the file is audio
- [x] **T1.3** Write request spec: POST upload with audio file returns `is_audio: true` and enqueues TranscribeAudioJob

### Phase 2: Frontend -- Audio recorder Stimulus controller

- [x] **T2.1** Create `app/javascript/controllers/audio_recorder_controller.js` with MediaRecorder API, timer, upload logic
- [x] **T2.2** Register controller in `app/javascript/controllers/index.js`
- [x] **T2.3** Add microphone button + recording indicator to `app/views/documents/edit.html.erb` header
- [x] **T2.4** Add CSS for recording indicator (pulsing dot, timer) in the edit view styles
- [x] **T2.5** Remove emoji from audio filename display in edit.html.erb (replace microphone emoji with heroicon)

### Phase 3: Testing

- [x] **T3.1** Write/update request spec for `POST /api/documents/:id/upload` with audio file -- verify TranscribeAudioJob enqueued
- [x] **T3.2** Write request spec for `POST /api/documents/:id/upload` with image file -- verify TranscribeAudioJob NOT enqueued
- [x] **T3.3** Run full test suite (`bundle exec rspec`) -- all tests pass

### Phase 4: Infrastructure (added during implementation)

- [x] **T4.1** Add FFmpeg audio conversion (WebM/OGG to WAV) in transcriber service (`whisper_service/app.py`)
- [x] **T4.2** Fix macOS AirPlay port 5000 conflict -- use port 5001 for local dev
- [x] **T4.3** Fix `bin/dev` to load `.env` file (was passing `--env /dev/null` to foreman)
