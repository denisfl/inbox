## Context

The Telegram bot currently handles text, photo, voice, audio, and generic document messages. When a user sends a PDF to the bot, it's saved as a generic file attachment but the text inside is not extracted. Users want to import PDF content (notes, articles, scanned receipts) into the notes system.

The existing `handle_document` method in `TelegramMessageHandler` already downloads the file and saves it — we need to branch on MIME type and add an OCR extraction path.

## Goals / Non-Goals

**Goals:**
- Accept PDF files sent to the Telegram bot
- Extract text from digital PDFs (embedded text, no image rendering needed)
- Fallback to Tesseract OCR for scanned/image-only PDFs
- Save extracted text as a document with text blocks (same structure as transcription output)
- Run extraction in a background job (async, non-blocking webhook response)

**Non-Goals:**
- OCR for image files (JPEG/PNG) sent as documents — out of scope for this story
- Table/layout preservation — plain text extraction only
- Handwriting recognition
- Multi-page progress tracking / streaming

## Decisions

### Decision: Two-tier extraction: `pdf-reader` gem first, Tesseract fallback

**Tier 1 — `pdf-reader` gem (pure Ruby):**
- Extracts embedded text from digital PDFs with no binary dependencies
- Fast, no Docker changes needed
- Handles 90% of use cases (notes, articles, exported documents)

**Tier 2 — Tesseract OCR (for scanned PDFs):**
- Used only when `pdf-reader` returns < 50 characters of text (heuristic for image-only PDFs)
- Requires `apk add tesseract-ocr poppler-utils` in Dockerfile (poppler's `pdftoppm` converts PDF pages to images)
- Adds ~30MB to Docker image
- Falls back gracefully: if Tesseract fails, save a placeholder text block

**Detection heuristic:** If `pdf-reader` extracts < 50 non-whitespace characters across all pages → treat as scanned → attempt Tesseract.

### Decision: OcrPdfJob handles PDF text extraction

New job `OcrPdfJob` receives `(document_id, blob_key)` — same pattern as `TranscribeAudioJob`. The document and file block are created synchronously in `TelegramMessageHandler` (bot gets immediate "processing" reply); extraction runs async.

### Decision: Handle PDF in existing `handle_document` with MIME type branch

In `TelegramMessageHandler#handle_document`, check `message.document.mime_type == 'application/pdf'`. If PDF: create document, enqueue `OcrPdfJob`. Otherwise: existing generic file save behavior.

### Decision: Gemfile addition

Add `gem 'pdf-reader'` to `Gemfile`. No gem for Tesseract needed — use `Open3.capture2` to shell out to `tesseract` CLI.

## Risks / Trade-offs

- **Risk:** Tesseract adds Docker image size (~30MB) → **Mitigation:** Acceptable; added only to production stage in Dockerfile.
- **Risk:** Large PDFs take long to OCR on RPi 5 → **Mitigation:** Job is async; timeout set generously (300s). User receives "processing" reply immediately.
- **Risk:** `pdf-reader` fails on encrypted/password-protected PDFs → **Mitigation:** Rescue `PDF::Reader::EncryptedPDFError`; save error text block and notify user.
- **Risk:** Tesseract not installed (image not rebuilt) → **Mitigation:** Rescue `Errno::ENOENT` from shell call; fall back to "could not OCR" message.
