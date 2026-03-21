# frozen_string_literal: true

require "telegram/bot"

module Api
  class TelegramController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_web_user!
    before_action :validate_telegram_secret
    before_action :validate_user_authorization

    def webhook
      Rails.logger.info("Telegram webhook received")

      # Parse raw JSON body directly to avoid params.permit! mass assignment warning
      update_hash = request.raw_post.present? ? JSON.parse(request.raw_post) : {}

      # Respond immediately to prevent Telegram retries (60s timeout).
      # Process asynchronously via background job.
      ProcessTelegramUpdateJob.perform_later(update_hash)

      head :ok
    rescue StandardError => e
      Rails.logger.error("Telegram webhook error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      # Always return 200 to prevent Telegram retries
      head :ok
    end

    private

    def validate_telegram_secret
      configured = AppSecret["TELEGRAM_WEBHOOK_SECRET_TOKEN"].to_s
      return true if configured.empty?

      header = request.headers["X-Telegram-Bot-Api-Secret-Token"] || request.headers["HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN"]

      unless ActiveSupport::SecurityUtils.secure_compare(header.to_s, configured)
        Rails.logger.warn("Invalid Telegram webhook secret token: #{header}")
        head :forbidden
        return false
      end

      true
    end

    def validate_user_authorization
      # Extract user_id from the update
      user_id = extract_user_id

      unless user_id.to_s == ENV["TELEGRAM_ALLOWED_USER_ID"]
        Rails.logger.warn("Unauthorized Telegram user: #{user_id}")
        send_telegram_reply("You are not authorized to use this bot.")
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

      bot = Telegram::Bot::Client.new(AppSecret["TELEGRAM_BOT_TOKEN"])
      bot.api.send_message(chat_id: chat_id, text: text)
    rescue StandardError => e
      Rails.logger.error("Failed to send Telegram reply: #{e.message}")
    end
  end
end
