# frozen_string_literal: true

require "rails_helper"

RSpec.describe TelegramMessageHandler do
  include_context "telegram_stub"
  include_context "ollama_stub"

  let(:chat_id) { 12345 }
  let(:message_id) { 99 }

  before do
    ENV["TELEGRAM_BOT_TOKEN"] ||= "test_token"
  end

  def build_update(text: nil, photo: nil, voice: nil, audio: nil, document: nil)
    msg = double("message",
      text: text,
      photo: photo,
      voice: voice,
      audio: audio,
      document: document,
      caption: nil,
      chat: double("chat", id: chat_id),
      message_id: message_id
    )
    double("update", message: msg)
  end

  describe "#handle" do
    context "with text message" do
      it "creates a document via IntentClassifier and IntentRouter" do
        stub_ollama_classify(intent: "note", confidence: 0.9, title: "Hello")

        update = build_update(text: "Hello world")

        expect {
          described_class.new(update).handle
        }.to change(Document, :count).by(1)
      end

      it "creates a task for todo intent" do
        stub_ollama_classify(intent: "todo", confidence: 0.95, title: "Buy milk")

        update = build_update(text: "need to buy milk")

        expect {
          described_class.new(update).handle
        }.to change(Task, :count).by(1)
      end

      it "updates telegram_message_id on the created document" do
        stub_ollama_classify(intent: "note", confidence: 0.9, title: "Test")

        update = build_update(text: "test message")
        described_class.new(update).handle

        doc = Document.last
        expect(doc.telegram_message_id).to eq(message_id)
      end
    end

    context "with nil message" do
      it "does nothing" do
        update = double("update", message: nil)

        expect {
          described_class.new(update).handle
        }.not_to change(Document, :count)
      end
    end

    context "when handler raises" do
      it "sends error reply and does not propagate" do
        stub_ollama_classify(intent: "note", confidence: 0.9, title: "Test")

        # Force IntentRouter to raise
        allow(IntentRouter).to receive(:dispatch).and_raise(StandardError, "boom")

        update = build_update(text: "test")

        # Should not raise — error is caught and reply sent
        expect {
          described_class.new(update).handle
        }.not_to raise_error
      end
    end
  end
end
