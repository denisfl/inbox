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
      # Stub the TelegramMessageHandler
      handler = instance_double(TelegramMessageHandler)
      allow(TelegramMessageHandler).to receive(:new).and_return(handler)
      allow(handler).to receive(:handle)

      post webhook_path, params: text_message_params, headers: valid_headers

      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for invalid secret token" do
      post webhook_path,
           params: text_message_params,
           headers: { "X-Telegram-Bot-Api-Secret-Token" => "wrong" }

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for unauthorized user (no retry)" do
      unauthorized_params = text_message_params.deep_dup
      unauthorized_params[:message][:from][:id] = 999999

      post webhook_path, params: unauthorized_params, headers: valid_headers

      expect(response).to have_http_status(:ok)
    end

    it "returns 200 even on handler error (prevent Telegram retries)" do
      handler = instance_double(TelegramMessageHandler)
      allow(TelegramMessageHandler).to receive(:new).and_return(handler)
      allow(handler).to receive(:handle).and_raise(StandardError, "boom")

      post webhook_path, params: text_message_params, headers: valid_headers

      expect(response).to have_http_status(:ok)
    end
  end
end
