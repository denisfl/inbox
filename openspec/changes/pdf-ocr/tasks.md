## 1. Gemfile

- [ ] 1.1 Add `gem 'pdf-reader'` to `Gemfile`
- [ ] 1.2 Run `bundle install`

## 2. Dockerfile — Tesseract & Poppler

- [ ] 2.1 In `Dockerfile`, in the production stage `apk add` block, add:
  ```
  tesseract-ocr \
  tesseract-ocr-data-rus \
  tesseract-ocr-data-eng \
  poppler-utils
  ```
  (`poppler-utils` provides `pdftoppm` for PDF→image conversion; `tesseract-ocr-data-rus` for Russian OCR)

## 3. TelegramMessageHandler — PDF Branch

- [ ] 3.1 In `app/services/telegram_message_handler.rb`, update `handle_document` to branch on MIME type:
  ```ruby
  def handle_document
    filename = message.document.file_name
    mime_type = message.document.mime_type

    if mime_type == 'application/pdf'
      handle_pdf_document(filename)
    else
      handle_generic_document(filename, mime_type)
    end
  end
  ```
- [ ] 3.2 Extract existing `handle_document` logic into `handle_generic_document(filename, mime_type)` (rename, no logic changes)
- [ ] 3.3 Implement `handle_pdf_document(filename)`:
  ```ruby
  def handle_pdf_document(filename)
    file_info = bot.api.get_file(file_id: message.document.file_id)
    file_url = "https://api.telegram.org/file/bot#{ENV['TELEGRAM_BOT_TOKEN']}/#{file_info.file_path}"
    downloaded_file = download_file(file_url)

    doc = Document.create!(
      title: "📄 #{filename}",
      source: 'telegram',
      telegram_chat_id: message.chat.id,
      telegram_message_id: message.message_id
    )

    file_block = doc.blocks.create!(
      block_type: 'file',
      position: 0,
      content: { filename: filename }.to_json
    )
    file_block.file.attach(
      io: downloaded_file,
      filename: filename,
      content_type: 'application/pdf'
    )

    OcrPdfJob.perform_later(doc.id, file_block.file.blob.key)
    send_reply("📄 Processing PDF...")
    Rails.logger.info("Queued PDF OCR for document #{doc.id}")
  end
  ```

## 4. OcrPdfJob

- [ ] 4.1 Create `app/jobs/ocr_pdf_job.rb`:
  ```ruby
  class OcrPdfJob < ApplicationJob
    queue_as :default

    def perform(document_id, blob_key)
      document = Document.find(document_id)
      file_block = document.blocks.find_by(block_type: 'file')
      return unless file_block&.file&.attached?

      pdf_data = file_block.file.download
      temp_pdf = Tempfile.new(['doc', '.pdf'], binmode: true)
      begin
        temp_pdf.write(pdf_data)
        temp_pdf.flush

        text = extract_text_from_pdf(temp_pdf.path)

        document.update!(title: text.truncate(50))
        document.blocks.create!(
          block_type: 'text',
          position: 0,
          content: { text: text }.to_json
        )

        notify_user(document, text.truncate(200)) if document.telegram_chat_id.present?
        Rails.logger.info("PDF OCR complete for document #{document_id}: #{text.length} chars")
      ensure
        temp_pdf.close
        temp_pdf.unlink
      end
    rescue PDF::Reader::EncryptedPDFError
      save_error_block(document_id, "❌ PDF is password-protected and cannot be read")
    rescue StandardError => e
      Rails.logger.error("OcrPdfJob failed for #{document_id}: #{e.class} - #{e.message}")
      save_error_block(document_id, "❌ PDF extraction failed: #{e.message}")
    end

    private

    def extract_text_from_pdf(pdf_path)
      # Tier 1: pdf-reader (digital PDFs)
      text = ''
      reader = PDF::Reader.new(pdf_path)
      reader.pages.each { |page| text += page.text.to_s + "\n" }
      text = text.strip

      # Tier 2: Tesseract fallback for scanned PDFs
      if text.gsub(/\s+/, '').length < 50
        Rails.logger.info("Low text from pdf-reader (#{text.length} chars) — attempting Tesseract OCR")
        text = tesseract_ocr(pdf_path)
      end

      text.presence || "❌ Could not extract text from this PDF"
    end

    def tesseract_ocr(pdf_path)
      require 'open3'
      temp_dir = Dir.mktmpdir
      begin
        # Convert PDF pages to PNG images
        Open3.capture2("pdftoppm -r 150 -png #{pdf_path} #{temp_dir}/page")

        # OCR each page image
        pages_text = Dir["#{temp_dir}/page-*.png"].sort.map do |img|
          out, _err, _status = Open3.capture2("tesseract #{img} stdout -l rus+eng")
          out
        end
        pages_text.join("\n").strip
      rescue Errno::ENOENT => e
        Rails.logger.warn("Tesseract not available: #{e.message}")
        ''
      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end

    def save_error_block(document_id, message_text)
      document = Document.find_by(id: document_id)
      return unless document
      document.blocks.create!(block_type: 'text', position: 0, content: { text: message_text }.to_json)
      notify_user(document, message_text) if document.telegram_chat_id.present?
    end

    def notify_user(document, text)
      bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
      bot.api.send_message(chat_id: document.telegram_chat_id, text: "📄 PDF extracted:\n\n#{text}")
    rescue StandardError => e
      Rails.logger.error("Failed to notify user: #{e.message}")
    end
  end
  ```

## 5. Verification

- [ ] 5.1 Send a digital PDF (e.g., exported notes) to the Telegram bot → verify document created with text content
- [ ] 5.2 Send a scanned PDF → verify Tesseract fallback runs (check logs for "attempting Tesseract OCR")
- [ ] 5.3 Send an encrypted PDF → verify error message saved in block and user notified
- [ ] 5.4 Rebuild Docker image after Dockerfile change: `docker compose ... build web worker`
- [ ] 5.5 Verify Tesseract installed in container: `docker exec -it <web_container> tesseract --version`
