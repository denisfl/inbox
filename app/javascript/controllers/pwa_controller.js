import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["installButton", "updateButton"];

  deferredPrompt = null;
  registration = null;

  connect() {
    this.registerServiceWorker();

    window.addEventListener("beforeinstallprompt", (e) => {
      e.preventDefault();
      this.deferredPrompt = e;
      this.showInstallButton();
    });

    window.addEventListener("appinstalled", () => {
      this.hideInstallButton();
      this.deferredPrompt = null;
    });

    // Auto-reload when a new SW takes over (after SKIP_WAITING)
    if (navigator.serviceWorker) {
      navigator.serviceWorker.addEventListener("controllerchange", () => {
        window.location.reload();
      });
    }
  }

  async registerServiceWorker() {
    if (!("serviceWorker" in navigator)) return;

    try {
      this.registration = await navigator.serviceWorker.register(
        "/service-worker.js",
        { scope: "/" },
      );

      // Proactively check for updates
      this.registration.update();

      // Watch for a new SW installing
      this.registration.addEventListener("updatefound", () => {
        const newWorker = this.registration.installing;
        if (!newWorker) return;

        newWorker.addEventListener("statechange", () => {
          // A new SW is installed and waiting — prompt user to update
          if (
            newWorker.state === "installed" &&
            navigator.serviceWorker.controller
          ) {
            this.showUpdateButton();
          }
        });
      });

      // A SW may already be waiting from a previous page load
      if (this.registration.waiting) {
        this.showUpdateButton();
      }
    } catch (error) {
      console.error("[PWA] Service Worker registration failed:", error);
    }
  }

  async install(event) {
    event.preventDefault();
    if (!this.deferredPrompt) return;

    this.deferredPrompt.prompt();
    await this.deferredPrompt.userChoice;
    this.deferredPrompt = null;
    this.hideInstallButton();
  }

  update(event) {
    event.preventDefault();

    // Send SKIP_WAITING to the *waiting* worker (not the current controller)
    const waiting = this.registration && this.registration.waiting;
    if (waiting) {
      waiting.postMessage({ type: "SKIP_WAITING" });
    }
    // controllerchange listener above will auto-reload the page
  }

  showInstallButton() {
    if (this.hasInstallButtonTarget) {
      this.installButtonTarget.classList.remove("hidden");
    }
  }

  hideInstallButton() {
    if (this.hasInstallButtonTarget) {
      this.installButtonTarget.classList.add("hidden");
    }
  }

  showUpdateButton() {
    if (this.hasUpdateButtonTarget) {
      this.updateButtonTarget.classList.remove("hidden");
    }
  }

  hideUpdateButton() {
    if (this.hasUpdateButtonTarget) {
      this.updateButtonTarget.classList.add("hidden");
    }
  }

  disconnect() {
    // no cleanup needed — global listeners are idempotent
  }
}
