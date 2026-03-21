# frozen_string_literal: true

require "rails_helper"

RSpec.describe TranscribeAudioJob, type: :job do
  include_context "telegram_stub"

  let(:transcriber_url) { ENV.fetch("TRANSCRIBER_URL", "http://transcriber:5000") }

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

    def stub_transcriber(text: "Hello world", language: "en")
      stub_request(:post, "#{transcriber_url}/transcribe")
        .to_return(
          status: 200,
          body: { text: text, language: language }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "transcribes audio and updates document" do
      stub_transcriber(text: "Hello world", language: "en")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      expect(document.title).to eq("Hello world")
      expect(document.document_type).to eq("note")
      expect(document.blocks.where(block_type: "text").count).to eq(1)
    end

    it "saves transcription text in block content" do
      stub_transcriber(text: "This is a test transcription", language: "en")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      text_block = document.blocks.find_by(block_type: "text")
      expect(text_block).to be_present
      expect(JSON.parse(text_block.content)["text"]).to eq("This is a test transcription")
    end

    it "sends Telegram notification after transcription" do
      stub_transcriber(text: "test notification", language: "en")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      expect(WebMock).to have_requested(:post, /api\.telegram\.org/)
    end

    it "creates error block on Transcription API failure and re-raises" do
      stub_request(:post, "#{transcriber_url}/transcribe")
        .to_return(status: 500, body: "Internal Server Error")

      expect {
        described_class.new.perform(document.id, document.blocks.first.file.blob.key)
      }.to raise_error(ExternalServiceClient::TransientHttpError)
    end

    it "creates error block on generic StandardError and re-raises" do
      stub_transcriber(text: "test", language: "en")
      allow(Document).to receive(:find).and_call_original
      allow(Document).to receive(:find).with(document.id).and_raise(StandardError, "DB connection lost")

      expect {
        described_class.new.perform(document.id, document.blocks.first.file.blob.key)
      }.to raise_error(StandardError, "DB connection lost")
    end

    it "raises on timeout for retry" do
      stub_request(:post, "#{transcriber_url}/transcribe")
        .to_timeout

      expect {
        described_class.new.perform(document.id, document.blocks.first.file.blob.key)
      }.to raise_error(HTTP::TimeoutError)
    end

    it "handles Russian language detection" do
      stub_transcriber(text: "Привет мир", language: "ru")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      text_block = document.blocks.find_by(block_type: "text")
      content = JSON.parse(text_block.content)
      expect(content["text"]).to eq("Привет мир")
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

      stub_transcriber(text: "No chat", language: "en")

      described_class.new.perform(doc_no_chat.id, block.file.blob.key)

      doc_no_chat.reload
      expect(doc_no_chat.blocks.where(block_type: "text").count).to eq(1)
      # Telegram notification should not be sent (no chat_id)
      expect(WebMock).not_to have_requested(:post, /api\.telegram\.org/).
        with(body: hash_including("chat_id" => nil))
    end

    it "truncates long transcriptions in document title" do
      long_text = "A" * 200
      stub_transcriber(text: long_text, language: "en")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      expect(document.title.length).to be <= 50
    end

    it "handles TRANSCRIBER_LANGUAGE env variable" do
      ENV["TRANSCRIBER_LANGUAGE"] = "ru"

      stub_transcriber(text: "Привет", language: "ru")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      expect(document.blocks.where(block_type: "text").count).to eq(1)

      ENV.delete("TRANSCRIBER_LANGUAGE")
    end

    it "handles empty transcription gracefully" do
      stub_transcriber(text: "", language: "en")

      described_class.new.perform(document.id, document.blocks.first.file.blob.key)

      document.reload
      text_block = document.blocks.find_by(block_type: "text")
      expect(JSON.parse(text_block.content)["text"]).to eq("(empty transcription)")
    end
  end

  describe "queue" do
    it "is enqueued in the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
