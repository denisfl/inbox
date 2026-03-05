---
id: audio-recording
artifact: proposal
---

## Why

Users can already attach pre-recorded audio files to documents, and voice messages sent via Telegram are transcribed automatically. However, there is no way to **record audio directly** within the document editor. This forces users to either use an external app to record and then attach, or rely solely on Telegram for voice input.

Adding in-browser audio recording closes this gap: a user opens a document, taps a microphone button, speaks, and the recording is saved and transcribed in-place -- the same flow as Telegram voice messages but within the web UI.

## What Changes

A "Record Audio" button in the document editor header that:

1. Opens browser microphone access (MediaRecorder API)
2. Shows a recording indicator with elapsed timer and stop button
3. On stop, uploads the recorded audio blob to the existing `/api/documents/:id/upload` endpoint
4. The upload endpoint detects audio content type and enqueues `TranscribeAudioJob`
5. The new audio block appears in the document's audio section with the standard player
6. Once transcription completes (async), the text block is added to the document

## Capabilities

### New Capabilities

- `audio-record-ui`: Stimulus controller (`audio_recorder_controller.js`) with MediaRecorder API, recording state management, timer display, and auto-upload on stop
- `audio-record-button`: Microphone button in simple editor header alongside existing image/file upload buttons
- `audio-upload-transcription`: Upload endpoint enhancement to detect audio files and enqueue TranscribeAudioJob automatically
- `audio-record-feedback`: Visual recording indicator (pulsing dot + timer) and status messages (uploading, transcribing)

### Modified Capabilities

- `upload-endpoint`: `/api/documents/:id/upload` now enqueues `TranscribeAudioJob` when the uploaded file has an audio content type

## Impact

- **No database changes** -- uses existing Block model with `block_type: "file"` and Active Storage `file` attachment
- **No new routes** -- uses existing upload endpoint
- **No new dependencies** -- MediaRecorder API is built into all modern browsers
- **Backend change is minimal** -- add 4 lines to the upload action to detect audio and enqueue job
