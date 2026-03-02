# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Telegram", type: :request do
  include_context "telegram_stub"

  let(:webhook_path) { "/api/telegram/webhook" }
  let(:allowed_user_id) { "123456" }
  let(:secret_token) { "test_secret" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("TELEGRAM_ALLOWED_USER_ID").and_return(allowed_user_id)
    allow(ENV).to receive(:[]).with("TELEGRAM_WEBHOOK_SECRET_TOKEN").and_return(secret_token)
    allow(ENV).to receive(:[]).with("TELEGRAM_BOT_TOKEN").and_return("fake_token")
  end

  let(:valid_headers) do
    { "X-Telegram-Bot-Api-Secret-Token" => secret_token }
  end

  let(:text_message_params) do
    {
      update_id: 1,
      message: {
        message_id: 1,
        from: { id: allowed_user_id.to_i, first_name: "Test" },
        chat: { id: allowed_user_id.to_i, type: "private" },
        date: Time.current.to_i,
        text: "Hello world"
      }
    }
  end

  describe "POST /api/telegram/webhook" do
    it "returns 200 for valid message" do
      # Use allow_any_instance_of to ensure the handler intercepts in-controller instantiation
      allow_any_instance_of(TelegramMessageHandler).to receive(:handle)

      post webhook_path, params: text_message_params, headers: valid_headers, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for invalid secret token" do
      post webhook_path,
           params: text_message_params,
           headers: { "X-Telegram-Bot-Api-Secret-Token" => "wrong" },
           as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for unauthorized user (no retry)" do
      unauthorized_params = text_message_params.deep_dup
      unauthorized_params[:message][:from][:id] = 999999

      post webhook_path, params: unauthorized_params, headers: valid_headers, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "returns 200 even on handler error (prevent Telegram retries)" do
      handler = instance_double(TelegramMessageHandler)
      allow(TelegramMessageHandler).to receive(:new).and_return(handler)
      allow(handler).to receive(:handle).and_raise(StandardError, "boom")

      post webhook_path, params: text_message_params, headers: valid_headers, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "extracts user_id from edited_message" do
      edited_params = {
        update_id: 2,
        edited_message: {
          message_id: 2,
          from: { id: 999999, first_name: "Other" },
          chat: { id: 999999, type: "private" },
          date: Time.current.to_i,
          text: "Edited text"
        }
      }

      post webhook_path, params: edited_params, headers: valid_headers, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "extracts user_id from callback_query" do
      callback_params = {
        update_id: 3,
        callback_query: {
          id: "123",
          from: { id: 999999, first_name: "Other" },
          message: {
            message_id: 3,
            chat: { id: 999999, type: "private" },
            date: Time.current.to_i
          },
          data: "some_callback"
        }
      }

      post webhook_path, params: callback_params, headers: valid_headers, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "skips validation when no secret token configured" do
      allow(ENV).to receive(:[]).with("TELEGRAM_WEBHOOK_SECRET_TOKEN").and_return("")

      handler = instance_double(TelegramMessageHandler)
      allow(TelegramMessageHandler).to receive(:new).and_return(handler)
      allow(handler).to receive(:handle)

      post webhook_path, params: text_message_params, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "handles send_telegram_reply failure gracefully for unauthorized user" do
      # Unauthorized user triggers send_telegram_reply which may fail
      unauthorized_params = text_message_params.deep_dup
      unauthorized_params[:message][:from][:id] = 999999

      # Make the Telegram API call fail
      bot_instance = instance_double(Telegram::Bot::Client)
      allow(Telegram::Bot::Client).to receive(:new).and_return(bot_instance)
      bot_api = double("bot_api")
      allow(bot_instance).to receive(:api).and_return(bot_api)
      allow(bot_api).to receive(:send_message).and_raise(StandardError, "Network error")

      post webhook_path, params: unauthorized_params, headers: valid_headers, as: :json

      # Should still return 200 (error is rescued)
      expect(response).to have_http_status(:ok)
    end
  end
end
