# frozen_string_literal: true

require "telegram/bot"

class ProcessTelegramUpdateJob < ApplicationJob
  queue_as :default

  # Only 1 retry — Telegram will also retry the webhook
  retry_on StandardError, wait: 5.seconds, attempts: 2

  def perform(update_hash)
    update = Telegram::Bot::Types::Update.new(update_hash)
    message = update.message
    return unless message

    message_id = message.message_id
    chat_id = message.chat&.id

    # ── Deduplication guard ──
    # Use Rails cache to prevent processing the same Telegram message twice.
    # The cache key expires after 1 hour (well beyond Telegram's retry window).
    if message_id && chat_id
      cache_key = "telegram_msg:#{chat_id}:#{message_id}"
      already_processed = Rails.cache.read(cache_key)

      if already_processed
        Rails.logger.info("ProcessTelegramUpdateJob: skipping duplicate message_id=#{message_id} chat=#{chat_id}")
        return
      end

      # Mark as processed BEFORE handling to prevent race conditions
      Rails.cache.write(cache_key, true, expires_in: 1.hour)
    end

    TelegramMessageHandler.new(update).handle
  end
end
