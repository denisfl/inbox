import { Controller } from "@hotwired/stimulus";

// Records audio via MediaRecorder API and uploads to the document.
//
// Usage:
//   <div data-controller="audio-recorder"
//        data-audio-recorder-document-id-value="42">
//     <button data-action="click->audio-recorder#toggleRecording"
//             data-audio-recorder-target="recordBtn">Record</button>
//     <div data-audio-recorder-target="recordingIndicator" class="hidden">
//       <span class="recording-dot"></span>
//       <span data-audio-recorder-target="timer">0:00</span>
//     </div>
//   </div>
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
    this._stopTimer();
    if (this.mediaRecorder?.state === "recording") {
      this.mediaRecorder.stop();
    }
  }

  async toggleRecording() {
    if (this.mediaRecorder?.state === "recording") {
      this.mediaRecorder.stop();
    } else {
      await this._startRecording();
    }
  }

  // ── Private ──────────────────────────────────────

  async _startRecording() {
    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (err) {
      console.error("Microphone access denied:", err);
      return;
    }

    // Prefer webm/opus, fall back to whatever the browser supports
    const mimeType = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
      ? "audio/webm;codecs=opus"
      : "audio/webm";

    this.mediaRecorder = new MediaRecorder(stream, { mimeType });
    this.audioChunks = [];

    this.mediaRecorder.ondataavailable = (e) => {
      if (e.data.size > 0) this.audioChunks.push(e.data);
    };

    this.mediaRecorder.onstop = () => {
      // Release microphone
      stream.getTracks().forEach((t) => t.stop());
      this._stopTimer();
      this._showIdle();
      this._uploadRecording();
    };

    this.mediaRecorder.onerror = () => {
      stream.getTracks().forEach((t) => t.stop());
      this._stopTimer();
      this._showIdle();
    };

    this.mediaRecorder.start();
    this._startTimer();
    this._showRecording();
  }

  async _uploadRecording() {
    const blob = new Blob(this.audioChunks, {
      type: this.mediaRecorder?.mimeType || "audio/webm",
    });
    const ext = blob.type.includes("webm") ? "webm" : "ogg";
    const file = new File([blob], `recording-${Date.now()}.${ext}`, {
      type: blob.type,
    });

    const formData = new FormData();
    formData.append("file", file);

    try {
      const token = document.querySelector('meta[name="auth-token"]')?.content;
      const res = await fetch(`/api/documents/${this.documentIdValue}/upload`, {
        method: "POST",
        headers: { Authorization: `Token token=${token}` },
        body: formData,
      });

      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      // Reload to show the new audio block and pending transcription
      window.location.reload();
    } catch (err) {
      console.error("Audio upload failed:", err);
    }
  }

  // ── Timer ────────────────────────────────────────

  _startTimer() {
    this.startTime = Date.now();
    this._updateTimerDisplay();
    this.timerInterval = setInterval(() => this._updateTimerDisplay(), 1000);
  }

  _stopTimer() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = null;
    }
    this.startTime = null;
  }

  _updateTimerDisplay() {
    if (!this.hasTimerTarget || !this.startTime) return;
    const elapsed = Math.floor((Date.now() - this.startTime) / 1000);
    const mins = Math.floor(elapsed / 60);
    const secs = elapsed % 60;
    this.timerTarget.textContent = `${mins}:${String(secs).padStart(2, "0")}`;
  }

  // ── UI state ─────────────────────────────────────

  _showRecording() {
    if (this.hasRecordBtnTarget) {
      this.recordBtnTarget.classList.add("is-recording");
    }
    if (this.hasRecordingIndicatorTarget) {
      this.recordingIndicatorTarget.classList.remove("hidden");
    }
  }

  _showIdle() {
    if (this.hasRecordBtnTarget) {
      this.recordBtnTarget.classList.remove("is-recording");
    }
    if (this.hasRecordingIndicatorTarget) {
      this.recordingIndicatorTarget.classList.add("hidden");
    }
  }
}
