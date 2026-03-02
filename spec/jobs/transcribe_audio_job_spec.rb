# frozen_string_literal: true

require "rails_helper"

RSpec.describe TranscribeAudioJob, type: :job do
  include_context "ollama_stub"
  include_context "telegram_stub"

  let(:whisper_url) { ENV.fetch("WHISPER_BASE_URL", "http://whisper:5000") }

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

    it "transcribes audio and updates document" do
      # Stub Whisper API
      stub_request(:post, "#{whisper_url}/transcribe")
        .to_return(
          status: 200,
          body: { text: "Hello world", language: "en" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub Ollama correction (first call) and intent classification (second call)
      stub_request(:post, "#{ENV.fetch('OLLAMA_BASE_URL', 'http://ollama:11434')}/api/generate")
        .to_return(
          { status: 200, body: { response: "Hello world" }.to_json, headers: { "Content-Type" => "application/json" } },
          { status: 200, body: { response: { intent: "note", confidence: 0.9, title: "Hello world", due_at: nil }.to_json }.to_json, headers: { "Content-Type" => "application/json" } }
        )

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      expect(document.title).to eq("Hello world")
      expect(document.blocks.where(block_type: "text").count).to eq(1)
    end

    it "creates error block on Whisper API failure" do
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
  end

  describe "queue" do
    it "is enqueued in the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
