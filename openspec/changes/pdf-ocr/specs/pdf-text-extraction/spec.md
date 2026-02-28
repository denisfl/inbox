## ADDED Requirements

### Requirement: Telegram bot accepts PDF documents

When a user sends a PDF file to the Telegram bot, the system SHALL process it as a text extraction task, not a generic file save.

#### Scenario: PDF message triggers extraction job

- **GIVEN** a user sends a PDF file to the Telegram bot
- **WHEN** the webhook processes the message
- **THEN** `TelegramMessageHandler` SHALL detect `mime_type == 'application/pdf'`
- **AND** SHALL create a document with a pending file block
- **AND** SHALL enqueue `OcrPdfJob` for async text extraction
- **AND** SHALL reply to the user: "📄 Processing PDF..."

#### Scenario: Non-PDF documents processed as before

- **GIVEN** a user sends a non-PDF document (e.g., `.docx`, `.mp3` as document)
- **WHEN** the webhook processes the message
- **THEN** the existing generic file save behavior SHALL apply (no text extraction)

### Requirement: Digital PDF text extracted via pdf-reader

For PDFs with embedded text, the system SHALL extract text using the `pdf-reader` gem.

#### Scenario: Digital PDF text extracted

- **GIVEN** a PDF with embedded selectable text
- **WHEN** `OcrPdfJob` processes it
- **THEN** all pages' text SHALL be concatenated and saved as a text block in the document
- **AND** the document title SHALL be set to the first 50 characters of the extracted text

#### Scenario: Encrypted PDF handled gracefully

- **GIVEN** a password-protected PDF
- **WHEN** `OcrPdfJob` attempts extraction
- **THEN** the job SHALL rescue the encryption error
- **AND** SHALL save a text block with message: "❌ PDF is password-protected and cannot be read"
- **AND** SHALL notify the user via Telegram if `telegram_chat_id` is present

### Requirement: Scanned PDF processed via Tesseract OCR

For PDFs with no embedded text (image-only), the system SHALL fall back to Tesseract OCR.

#### Scenario: Scanned PDF — Tesseract fallback triggered

- **GIVEN** a PDF where `pdf-reader` extracts fewer than 50 non-whitespace characters
- **WHEN** `OcrPdfJob` detects the low character count
- **THEN** the job SHALL convert PDF pages to images (via `pdftoppm`) and run `tesseract` on each
- **AND** the OCR output SHALL be saved as a text block

#### Scenario: Tesseract not available — fallback message

- **GIVEN** Tesseract is not installed in the container
- **WHEN** the OCR fallback is attempted
- **THEN** the job SHALL rescue the error and save: "❌ Scanned PDF detected but OCR is unavailable"

### Requirement: Extraction result saved as document text block

After successful extraction, the document SHALL be updated with the extracted text.

#### Scenario: Text block created after extraction

- **WHEN** PDF text extraction succeeds
- **THEN** a `text` block SHALL be created with `content: { text: <extracted_text> }`
- **AND** the document title SHALL be updated to a truncated version of the extracted text
- **AND** if a Telegram `chat_id` is available, the user SHALL receive a confirmation reply with a text preview
