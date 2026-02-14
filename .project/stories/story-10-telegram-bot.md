# Story 10: Telegram Bot Integration

**Priority:** P0 (Critical)  
**Complexity:** High  
**Estimated Effort:** 3-4 days  
**Dependencies:** Story 2 (Data Models)  
**Status:** Blocked

---

## User Story

As a user, I want to send messages to a Telegram bot so that I can capture notes from my phone.

---

## Acceptance Criteria

### ✅ Bot Configuration

- [ ] Bot created via @BotFather
- [ ] Bot token stored in `TELEGRAM_BOT_TOKEN` env variable
- [ ] Webhook URL configured: `https://your-domain.com/api/telegram/webhook`
- [ ] Webhook secret token configured for validation

### ✅ Webhook Endpoint

- [ ] Route: `POST /api/telegram/webhook`
- [ ] Controller: `Api::TelegramController#webhook`
- [ ] Webhook signature validation
- [ ] Request parsing (Telegram Update format)
- [ ] Response: `200 OK` (within 60 seconds)

### ✅ Message Handlers

**Text Messages:**

- [ ] Extract text content
- [ ] Create Document with TextBlock
- [ ] Set source: 'telegram'
- [ ] Reply with confirmation: "✅ Note saved"

**Photo Messages:**

- [ ] Download photo from Telegram API
- [ ] Create Document with ImageBlock
- [ ] Store photo with ActiveStorage
- [ ] Caption as TextBlock (if present)
- [ ] Reply with confirmation

**File Attachments:**

- [ ] Download file from Telegram API
- [ ] Create Document with FileBlock
- [ ] Store file with ActiveStorage
- [ ] Supported types: PDF, DOCX, TXT, etc.
- [ ] Reply with confirmation

**Voice Messages:**

- [ ] Download voice file (.ogg)
- [ ] Create Document with placeholder text: "🎤 Transcribing..."
- [ ] Queue transcription job (Story 11)
- [ ] Reply: "🎤 Transcribing your voice note..."

### ✅ Error Handling

- [ ] Invalid signature → 401 Unauthorized
- [ ] Unsupported message type → Reply: "❌ Unsupported message type"
- [ ] Download failure → Reply: "❌ Failed to download file"
- [ ] Timeout (>60s) → Log error, queue retry

### ✅ Testing

- [ ] RSpec request tests for webhook:
  - Text message handling
  - Photo message handling
  - File message handling
  - Voice message handling
  - Invalid signature
  - Unsupported types
- [ ] VCR for Telegram API mocking
- [ ] Factory for Telegram Update payloads
- [ ] Code coverage: 80%+

---

## Technical Implementation

### 1. Install Gem

```ruby
# Gemfile
gem 'telegram-bot-ruby'
```

### 2. Configure Routes

```ruby
# config/routes.rb
namespace :api do
  post 'telegram/webhook', to: 'telegram#webhook'
end
```

### 3. Create Controller

```ruby
# app/controllers/api/telegram_controller.rb
class Api::TelegramController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :validate_webhook_signature

  def webhook
    update = Telegram::Bot::Types::Update.new(params.permit!.to_h)

    TelegramMessageHandler.new(update).handle

    head :ok
  rescue => e
    Rails.logger.error("Telegram webhook error: #{e.message}")
    head :ok # Always return 200 to Telegram
  end

  private

  def validate_webhook_signature
    # Implement signature validation
  end
end
```

### 4. Create Message Handler

```ruby
# app/services/telegram_message_handler.rb
class TelegramMessageHandler
  def initialize(update)
    @update = update
    @message = update.message
  end

  def handle
    case
    when text_message?
      handle_text
    when photo_message?
      handle_photo
    when voice_message?
      handle_voice
    when document_message?
      handle_document
    else
      send_reply("❌ Unsupported message type")
    end
  end

  private

  def text_message?
    @message.text.present?
  end

  def handle_text
    doc = Document.create!(
      title: @message.text.truncate(50),
      source: 'telegram'
    )
    doc.blocks.create!(
      type: 'TextBlock',
      position: 0,
      data: { text: @message.text }
    )
    send_reply("✅ Note saved")
  end

  # ... other handlers
end
```

### 5. Set Webhook

```bash
# Script to set webhook
curl -X POST https://api.telegram.org/bot<TOKEN>/setWebhook \
  -d url=https://your-domain.com/api/telegram/webhook \
  -d secret_token=<SECRET>
```

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Webhook endpoint working
- [ ] All message types handled
- [ ] Tests passing (80%+ coverage)
- [ ] Bot responds to messages
- [ ] Error handling robust
- [ ] Documentation updated

---

## Notes

- Telegram requires response within 60 seconds
- Queue heavy operations (transcription) in background
- Always return 200 OK to prevent retries
- Use VCR for testing to avoid real API calls
- Store Telegram file_id for future reference
