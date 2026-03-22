// Entry point for the build script in your package.json
import "@hotwired/turbo-rails";
import "./controllers";

import "@37signals/lexxy";

// Workaround for Lexxy 0.8.5-beta paste duplication bug:
// Lexxy's Clipboard#paste() does not call event.preventDefault() when handling
// rich-text (HTML) pastes via #handlePastedFiles. On Safari, the browser inserts
// the clipboard content into the contentEditable before beforeinput can prevent it,
// resulting in duplicated pasted blocks. This capture-phase listener ensures the
// browser's default paste is always prevented for Lexxy editors.
document.addEventListener(
  "paste",
  (event) => {
    if (event.target.closest?.("[contenteditable]")?.closest("lexxy-editor")) {
      event.preventDefault();
    }
  },
  true,
);
