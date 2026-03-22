import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "providerSelect",
    "s3Fields",
    "dropboxFields",
    "google_driveFields",
    "onedriveFields",
  ];

  toggleFields() {
    const provider = this.providerSelectTarget.value;
    const allProviders = ["s3", "dropbox", "google_drive", "onedrive"];

    allProviders.forEach((p) => {
      const targetName = `${p}Fields`;
      if (
        this[
          `has${targetName.charAt(0).toUpperCase() + targetName.slice(1)}Target`
        ]
      ) {
        const el = this[`${targetName}Target`];
        el.style.display = provider === p ? "" : "none";
      }
    });
  }
}
