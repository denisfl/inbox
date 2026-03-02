## Why

Users want to send PDF files to the Telegram bot and have the text extracted and saved as a document — the same workflow as voice notes. Currently only audio messages are processed; PDF `document` messages are ignored.

## What Changes

- Handle Telegram `document` messages where `mime_type` is `application/pdf`
- Download the PDF from Telegram, run OCR to extract text, save as a new document with text blocks
- Support both digital PDFs (embedded text via `pdf-reader` gem) and scanned PDFs (via Tesseract OCR)

## Capabilities

### New Capabilities

- `pdf-text-extraction`: Telegram bot receives a PDF document message. Text is extracted (embedded text first, then OCR fallback for scanned/image PDFs). Extracted text is saved as blocks in a new document.

### New Components

- `OcrPdfJob`: Background job — downloads PDF from Telegram, extracts text via `pdf-reader` gem (digital) or `rtesseract`/`tesseract-ocr` CLI (scanned), creates document with text blocks
- Telegram handler update: `TelegramMessageHandler` — handle `document` messages with `application/pdf` MIME type

## Impact

- **Code**: `TelegramMessageHandler` — detect PDF document messages; `OcrPdfJob` (new job); possibly extend `whisper_service` or add a new OCR microservice
- **Dependencies**: `pdf-reader` gem (pure Ruby, no binary) for digital PDFs; `tesseract-ocr` Alpine package for scanned PDFs (adds Docker image size)
- **Docker**: `Dockerfile` — `apk add tesseract-ocr` if scanned PDF support needed
- **No Whisper changes needed** — OCR is text extraction, not audio
- **Accuracy**: digital PDFs are perfect; scanned PDFs depend on scan quality and Tesseract training data
