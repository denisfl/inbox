import { Controller } from "@hotwired/stimulus";

// Custom audio player with speed controls
export default class extends Controller {
  static targets = [
    "audio",
    "playButton",
    "progressBar",
    "progressFill",
    "timeDisplay",
    "speedButton",
  ];

  // Playback speeds
  speeds = [1.0, 1.25, 1.5, 1.75, 2.0];
  currentSpeedIndex = 0;

  connect() {
    console.log("Audio player connected");
    console.log("Audio element:", this.audioTarget);
    console.log(
      "Has all targets:",
      this.hasAudioTarget,
      this.hasPlayButtonTarget,
      this.hasProgressBarTarget,
    );

    this.audioTarget.playbackRate = 1.0;

    // Update duration when metadata loads
    this.audioTarget.addEventListener("loadedmetadata", () => {
      console.log(
        "Audio metadata loaded, duration:",
        this.audioTarget.duration,
      );
      this.updateTimeDisplay();
    });

    // Error handling
    this.audioTarget.addEventListener("error", (e) => {
      console.error("Audio error:", e, this.audioTarget.error);
    });
  }

  togglePlay() {
    const audio = this.audioTarget;
    const playIcon = this.playButtonTarget.querySelector(".icon-play");
    const pauseIcon = this.playButtonTarget.querySelector(".icon-pause");

    if (audio.paused) {
      audio.play();
      playIcon.style.display = "none";
      pauseIcon.style.display = "block";
    } else {
      audio.pause();
      playIcon.style.display = "block";
      pauseIcon.style.display = "none";
    }
  }

  updateProgress() {
    const audio = this.audioTarget;
    const progress = (audio.currentTime / audio.duration) * 100;

    this.progressFillTarget.style.width = `${progress}%`;
    this.updateTimeDisplay();
  }

  seek(event) {
    const progressBar = this.progressBarTarget;
    const rect = progressBar.getBoundingClientRect();
    const clickX = event.clientX - rect.left;
    const percentage = clickX / rect.width;

    this.audioTarget.currentTime = this.audioTarget.duration * percentage;
  }

  cycleSpeed() {
    this.currentSpeedIndex = (this.currentSpeedIndex + 1) % this.speeds.length;
    const newSpeed = this.speeds[this.currentSpeedIndex];

    this.audioTarget.playbackRate = newSpeed;
    this.speedButtonTarget.textContent = `${newSpeed}x`;
  }

  updateTimeDisplay() {
    const audio = this.audioTarget;
    const current = this.formatTime(audio.currentTime);
    const duration = this.formatTime(audio.duration);

    this.timeDisplayTarget.textContent = `${current} / ${duration}`;
  }

  formatTime(seconds) {
    if (isNaN(seconds)) return "0:00";

    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  }
}
