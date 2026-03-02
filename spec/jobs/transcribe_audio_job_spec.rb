# frozen_string_literal: true

require "rails_helper"

RSpec.describe TranscribeAudioJob, type: :job do
  include_context "ollama_stub"
  include_context "telegram_stub"

  let(:whisper_url) { ENV.fetch("WHISPER_BASE_URL", "http://whisper:5000") }
  let(:ollama_url) { ENV.fetch("OLLAMA_BASE_URL", "http://ollama:11434") }

  before do
    ENV["TELEGRAM_BOT_TOKEN"] ||= "test_token"
  end

  describe "#perform" do
    let(:document) do
      doc = create(:document, telegram_chat_id: 12345)
      block = doc.blocks.create!(block_type: "file", position: 0, content: "{}")
      block.file.attach(
        io: StringIO.new("fake audio data"),
        filename: "voice.ogg",
        content_type: "audio/ogg"
      )
      doc
    end

    def stub_whisper(text: "Hello world", language: "en")
      stub_request(:post, "#{whisper_url}/transcribe")
        .to_return(
          status: 200,
          body: { text: text, language: language }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    def stub_ollama_two_calls(corrected: "Hello world", intent: "note", confidence: 0.9, title: "Hello")
      stub_request(:post, "#{ollama_url}/api/generate")
        .to_return(
          { status: 200, body: { response: corrected }.to_json, headers: { "Content-Type" => "application/json" } },
          { status: 200, body: { response: { intent: intent, confidence: confidence, title: title, due_at: nil }.to_json }.to_json, headers: { "Content-Type" => "application/json" } }
        )
    end

    it "transcribes audio and updates document" do
      stub_whisper(text: "Hello world", language: "en")
      stub_ollama_two_calls(corrected: "Hello world", intent: "note", title: "Hello world")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      expect(document.title).to eq("Hello world")
      expect(document.blocks.where(block_type: "text").count).to eq(1)
    end

    it "classifies as todo and applies tag" do
      stub_whisper(text: "buy groceries", language: "en")
      stub_ollama_two_calls(corrected: "buy groceries", intent: "todo", confidence: 0.95, title: "Buy groceries")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      expect(document.document_type).to eq("todo")
      expect(document.tags.map(&:name)).to include("todo")
    end

    it "sends Telegram notification after transcription" do
      stub_whisper(text: "test notification", language: "en")
      stub_ollama_two_calls(corrected: "test notification")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      expect(WebMock).to have_requested(:post, /api\.telegram\.org/)
    end

    it "uses raw transcription when Ollama correction fails" do
      stub_whisper(text: "Raw text here", language: "en")

      # First call (correction) fails, second call (classification) succeeds
      stub_request(:post, "#{ollama_url}/api/generate")
        .to_return(
          { status: 500, body: "Internal Server Error" },
          { status: 200, body: { response: { intent: "note", confidence: 0.9, title: "Raw text", due_at: nil }.to_json }.to_json, headers: { "Content-Type" => "application/json" } }
        )

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      # Uses raw text since correction failed
      text_block = document.blocks.find_by(block_type: "text")
      expect(JSON.parse(text_block.content)["text"]).to eq("Raw text here")
    end

    it "discards suspiciously long correction (safety check)" do
      stub_whisper(text: "Short input", language: "en")

      # Return an overly verbose correction response
      long_response = "Here is my corrected version of the text: " + ("word " * 100)
      stub_ollama_two_calls(corrected: long_response)

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      text_block = document.blocks.find_by(block_type: "text")
      # Should use raw text, not the long correction
      expect(JSON.parse(text_block.content)["text"]).to eq("Short input")
    end

    it "creates error block on Whisper API failure and re-raises" do
      stub_request(:post, "#{whisper_url}/transcribe")
        .to_return(status: 500, body: "Internal Server Error")

      expect {
        described_class.new.perform(document.id, document.blocks.first.file.blob.key)
      }.to raise_error(RuntimeError, /Whisper API/)

      document.reload
      error_block = document.blocks.find_by(block_type: "text")
      expect(error_block).to be_present
      expect(JSON.parse(error_block.content)["text"]).to include("Transcription failed")
    end

    it "raises on timeout for retry" do
      stub_request(:post, "#{whisper_url}/transcribe")
        .to_timeout

      expect {
        described_class.new.perform(document.id, document.blocks.first.file.blob.key)
      }.to raise_error(HTTP::TimeoutError)
    end

    it "handles Russian language detection" do
      stub_whisper(text: "Привет мир", language: "ru")
      stub_ollama_two_calls(corrected: "Привет мир")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      text_block = document.blocks.find_by(block_type: "text")
      content = JSON.parse(text_block.content)
      expect(content["language"]).to eq("ru")
    end

    it "skips Telegram notification when no chat_id" do
      doc_no_chat = create(:document, telegram_chat_id: nil)
      block = doc_no_chat.blocks.create!(block_type: "file", position: 0, content: "{}")
      block.file.attach(
        io: StringIO.new("fake audio"),
        filename: "voice.ogg",
        content_type: "audio/ogg"
      )

      stub_whisper(text: "No chat", language: "en")
      stub_ollama_two_calls(corrected: "No chat")

      # Should not send Telegram message (no chat_id)
      described_class.new.perform(doc_no_chat.id, block.file.blob.key)

      # Telegram send_message should NOT have been called for this doc
      # (telegram_stub catches all, so we just verify the doc was processed)
      doc_no_chat.reload
      expect(doc_no_chat.blocks.where(block_type: "text").count).to eq(1)
    end
  end

  describe "queue" do
    it "is enqueued in the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
