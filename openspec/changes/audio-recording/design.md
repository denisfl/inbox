---
id: audio-recording
artifact: design
---

## Architecture

### Overview

```
User clicks mic button
       |
       v
[audio_recorder_controller.js]  -- MediaRecorder API
       |  (on stop)
       v
POST /api/documents/:id/upload   -- existing endpoint
       |
       v
[Api::DocumentsController#upload]
       |  detect audio content_type
       |  create Block(block_type: "file") + attach audio
       |  enqueue TranscribeAudioJob
       v
[TranscribeAudioJob]             -- existing job
       |  POST to Parakeet v3
       v
Document updated with text block (transcription)
```

### Frontend: audio_recorder_controller.js

New Stimulus controller managing the full recording lifecycle.

```javascript
// app/javascript/controllers/audio_recorder_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["recordBtn", "recordingIndicator", "timer"];
  static values = { documentId: Number };

  connect() {
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.timerInterval = null;
    this.startTime = null;
  }

  disconnect() {
    this.stopTimer();
    if (this.mediaRecorder?.state === "recording") {
      this.mediaRecorder.stop();
    }
  }

  async toggleRecording() {
    if (this.mediaRecorder?.state === "recording") {
      this.mediaRecorder.stop();
    } else {
      await this.startRecording();
    }
  }

  async startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

      // Prefer webm/opus, fall back to whatever the browser supports
      const mimeType = MediaRecorder.isTypeSupported("audio/webm;codecs=opus") ? "audio/webm;codecs=opus" : "audio/webm";

      this.mediaRecorder = new MediaRecorder(stream, { mimeType });
      this.audioChunks = [];

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) this.audioChunks.push(e.data);
      };

      this.mediaRecorder.onstop = () => {
        stream.getTracks().forEach((t) => t.stop()); // release mic
        this.stopTimer();
        this.showIdle();
        this.uploadRecording();
      };

      this.mediaRecorder.start();
      this.startTimer();
      this.showRecording();
    } catch (err) {
      console.error("Microphone access denied:", err);
      // Optionally show a user-facing message
    }
  }

  // Timer
  startTimer() {
    /* set interval, update timerTarget with mm:ss */
  }
  stopTimer() {
    /* clear interval */
  }

  // UI state
  showRecording() {
    /* swap mic icon to stop icon, show pulsing indicator + timer */
  }
  showIdle() {
    /* restore mic icon, hide indicator */
  }

  // Upload
  async uploadRecording() {
    const blob = new Blob(this.audioChunks, { type: this.mediaRecorder.mimeType });
    const ext = blob.type.includes("webm") ? "webm" : "ogg";
    const file = new File([blob], `recording-${Date.now()}.${ext}`, { type: blob.type });

    const formData = new FormData();
    formData.append("file", file);

    const token = document.querySelector('meta[name="auth-token"]')?.content;
    const res = await fetch(`/api/documents/${this.documentIdValue}/upload`, {
      method: "POST",
      headers: { Authorization: `Token token=${token}` },
      body: formData,
    });

    if (res.ok) {
      // Reload page to show new audio block + pending transcription
      window.location.reload();
    }
  }
}
```

### Frontend: UI placement in edit.html.erb

Add a microphone button in the simple editor header, next to the existing image and file upload buttons:

```erb
<%# Record audio button %>
<button type="button"
        class="simple-editor-upload-btn"
        title="Record audio"
        data-controller="audio-recorder"
        data-audio-recorder-document-id-value="<%= @document.id %>"
        data-action="click->audio-recorder#toggleRecording"
        data-audio-recorder-target="recordBtn">
  <%= heroicon :microphone, width: 16, height: 16 %>
</button>

<%# Recording indicator (hidden by default) %>
<div class="simple-editor-recording-indicator hidden"
     data-audio-recorder-target="recordingIndicator">
  <span class="recording-dot"></span>
  <span data-audio-recorder-target="timer">0:00</span>
</div>
```

### Frontend: CSS for recording indicator

```css
.recording-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #ef4444;
  display: inline-block;
  animation: pulse-recording 1s ease-in-out infinite;
}

@keyframes pulse-recording {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.3;
  }
}

.simple-editor-recording-indicator {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.8rem;
  color: #ef4444;
  font-variant-numeric: tabular-nums;
}
```

### Backend: Upload endpoint enhancement

In `Api::DocumentsController#upload`, after creating the file block, detect audio content type and enqueue transcription:

```ruby
# After block.file.attach(file):
is_audio = file.content_type.to_s.start_with?("audio/")
if is_audio
  TranscribeAudioJob.perform_later(block.document_id, block.file.blob.key)
end
```

No new routes, controllers, or models needed.

### Supported Audio Formats

MediaRecorder produces `audio/webm;codecs=opus` on Chrome/Edge/Firefox. Safari produces `audio/mp4`. The Parakeet v3 transcription service uses FFmpeg to convert any format to WAV before processing, so all browser formats are supported.

### Error Handling

| Scenario                   | Handling                                         |
| -------------------------- | ------------------------------------------------ |
| Microphone access denied   | Log error, no UI change (button stays idle)      |
| Recording fails mid-stream | `onerror` stops recording, releases mic          |
| Upload fails               | Console error, no audio block created            |
| Transcription fails        | TranscribeAudioJob retries (Sidekiq, 3 attempts) |
