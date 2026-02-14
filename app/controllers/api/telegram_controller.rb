# frozen_string_literal: true

require 'telegram/bot'

module Api
  class TelegramController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :validate_user_authorization

    def webhook
      Rails.logger.info("Telegram webhook received: #{params.inspect}")

      update = Telegram::Bot::Types::Update.new(params.permit!.to_h)

      # Process message asynchronously to respond within 60s requirement
      TelegramMessageHandler.new(update).handle

      head :ok
    rescue StandardError => e
      Rails.logger.error("Telegram webhook error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      # Always return 200 to prevent Telegram retries
      head :ok
    end

    private

    def validate_user_authorization
      # Extract user_id from the update
      user_id = extract_user_id

      unless user_id.to_s == ENV['TELEGRAM_ALLOWED_USER_ID']
        Rails.logger.warn("Unauthorized Telegram user: #{user_id}")
        send_telegram_reply("❌ You are not authorized to use this bot.")
        head :ok
        return false
      end

      true
    end

    def extract_user_id
      # Handle different update types
      if params[:message].present?
        params[:message][:from][:id]
      elsif params[:edited_message].present?
        params[:edited_message][:from][:id]
      elsif params[:callback_query].present?
        params[:callback_query][:from][:id]
      end
    end

    def send_telegram_reply(text)
      chat_id = params.dig(:message, :chat, :id) ||
                params.dig(:edited_message, :chat, :id) ||
                params.dig(:callback_query, :message, :chat, :id)

      return unless chat_id

      bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
      bot.api.send_message(chat_id: chat_id, text: text)
    rescue StandardError => e
      Rails.logger.error("Failed to send Telegram reply: #{e.message}")
    end
  end
end
