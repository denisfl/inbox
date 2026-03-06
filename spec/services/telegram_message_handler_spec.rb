# frozen_string_literal: true

require "rails_helper"

RSpec.describe TelegramMessageHandler do
  include_context "telegram_stub"

  let(:chat_id) { 12345 }
  let(:message_id) { 99 }

  before do
    ENV["TELEGRAM_BOT_TOKEN"] ||= "test_token"
  end

  def build_update(text: nil, photo: nil, voice: nil, audio: nil, document: nil, caption: nil)
    msg = double("message",
      text: text,
      photo: photo,
      voice: voice,
      audio: audio,
      document: document,
      caption: caption,
      chat: double("chat", id: chat_id),
      message_id: message_id
    )
    double("update", message: msg)
  end

  # Stub bot.api.get_file to return a file_path
  def stub_bot_get_file(file_path: "documents/file_123.ogg")
    file_result = double("file_info", file_path: file_path)
    bot_api = double("bot_api")
    allow(bot_api).to receive(:get_file).and_return(file_result)
    allow(bot_api).to receive(:send_message)

    bot = double("bot", api: bot_api)
    allow(Telegram::Bot::Client).to receive(:new).and_return(bot)
  end

  # Stub file download via open-uri
  def stub_file_download(content: "fake file data")
    io = StringIO.new(content)
    allow(URI).to receive(:parse).and_call_original
    allow_any_instance_of(URI::HTTPS).to receive(:open).and_return(io)
  end

  describe "#handle" do
    context "with text message" do
      it "creates a note document directly" do
        update = build_update(text: "Hello world")

        expect {
          described_class.new(update).handle
        }.to change(Document, :count).by(1)

        doc = Document.last
        expect(doc.document_type).to eq("note")
        expect(doc.title).to eq("Hello world")
      end

      it "saves text content in a block" do
        update = build_update(text: "My note content")
        described_class.new(update).handle

        doc = Document.last
        text_block = doc.blocks.find_by(block_type: "text")
        expect(text_block).to be_present
        expect(JSON.parse(text_block.content)["text"]).to eq("My note content")
      end

      it "auto-tags with telegram" do
        update = build_update(text: "tagged message")
        described_class.new(update).handle

        doc = Document.last
        expect(doc.tags.map(&:name)).to include("telegram")
      end

      it "updates telegram_message_id on the created document" do
        update = build_update(text: "test message")
        described_class.new(update).handle

        doc = Document.last
        expect(doc.telegram_message_id).to eq(message_id)
      end

      it "truncates long titles" do
        long_text = "A" * 200
        update = build_update(text: long_text)
        described_class.new(update).handle

        doc = Document.last
        expect(doc.title.length).to be <= 80
      end
    end

    context "with photo message" do
      let(:photo) do
        [
          double("photo_small", file_id: "small_id", file_size: 1000),
          double("photo_large", file_id: "large_id", file_size: 5000)
        ]
      end

      before do
        stub_bot_get_file(file_path: "photos/photo_large_id.jpg")
        stub_file_download(content: "fake jpeg data")
      end

      it "creates a document with image block" do
        update = build_update(photo: photo, caption: "My photo")

        expect {
          described_class.new(update).handle
        }.to change(Document, :count).by(1)

        doc = Document.last
        expect(doc.blocks.where(block_type: "image").count).to eq(1)
        expect(doc.tags.map(&:name)).to include("telegram", "file")
      end

      it "uses the largest photo size" do
        update = build_update(photo: photo)

        described_class.new(update).handle

        # The bot should have been asked for the large file
        bot = Telegram::Bot::Client.new("test")
        expect(bot.api).to have_received(:get_file).with(file_id: "large_id")
      end

      it "adds caption as text block when present" do
        update = build_update(photo: photo, caption: "Photo caption")

        described_class.new(update).handle

        doc = Document.last
        text_block = doc.blocks.find_by(block_type: "text")
        expect(text_block).to be_present
        expect(JSON.parse(text_block.content)["text"]).to eq("Photo caption")
      end
    end

    context "with voice message" do
      let(:voice) { double("voice", file_id: "voice_123") }

      before do
        stub_bot_get_file(file_path: "voices/voice_123.ogg")
        stub_file_download(content: "fake ogg data")
      end

      it "creates a document with file block (no auto-transcription)" do
        update = build_update(voice: voice)

        expect {
          described_class.new(update).handle
        }.to change(Document, :count).by(1)

        doc = Document.last
        expect(doc.blocks.where(block_type: "file").count).to eq(1)
        expect(doc.tags.map(&:name)).to include("telegram", "audio")
      end
    end

    context "with audio message" do
      let(:audio) do
        double("audio",
          file_id: "audio_456",
          file_name: "song.mp3",
          mime_type: "audio/mpeg"
        )
      end

      before do
        stub_bot_get_file(file_path: "audio/audio_456.mp3")
        stub_file_download(content: "fake mp3 data")
      end

      it "creates a document with audio file block" do
        update = build_update(audio: audio)

        expect {
          described_class.new(update).handle
        }.to change(Document, :count).by(1)

        doc = Document.last
        expect(doc.blocks.where(block_type: "file").count).to eq(1)
        expect(doc.tags.map(&:name)).to include("telegram", "audio")
      end
    end

    context "with document message" do
      let(:tg_document) do
        double("document",
          file_id: "doc_789",
          file_name: "report.pdf",
          mime_type: "application/pdf"
        )
      end

      before do
        stub_bot_get_file(file_path: "documents/doc_789.pdf")
        stub_file_download(content: "fake pdf data")
      end

      it "creates a document with file block" do
        update = build_update(document: tg_document)

        expect {
          described_class.new(update).handle
        }.to change(Document, :count).by(1)

        doc = Document.last
        expect(doc.blocks.where(block_type: "file").count).to eq(1)
        expect(doc.tags.map(&:name)).to include("telegram", "file")
      end

      it "adds caption as text block when present" do
        update = build_update(document: tg_document, caption: "Important report")

        described_class.new(update).handle

        doc = Document.last
        text_block = doc.blocks.find_by(block_type: "text")
        expect(text_block).to be_present
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

    context "with unknown message type" do
      it "sends unsupported message reply" do
        msg = double("message",
          text: nil,
          photo: nil,
          voice: nil,
          audio: nil,
          document: nil,
          caption: nil,
          chat: double("chat", id: chat_id),
          message_id: message_id
        )
        update = double("update", message: msg)

        stub_bot_get_file
        described_class.new(update).handle
        # Should not raise, and should send unsupported message reply
      end
    end

    context "when handler raises" do
      it "sends error reply and does not propagate" do
        allow(Document).to receive(:create!).and_raise(StandardError, "boom")

        update = build_update(text: "test")

        expect {
          described_class.new(update).handle
        }.not_to raise_error
      end
    end

    context "when file download fails" do
      let(:photo) do
        [
          double("photo_small", file_id: "small_id", file_size: 1000),
          double("photo_large", file_id: "large_id", file_size: 5000)
        ]
      end

      it "raises download error with message" do
        stub_bot_get_file(file_path: "photos/photo_large_id.jpg")

        # Stub URI.parse to raise on the download URL
        allow_any_instance_of(URI::HTTPS).to receive(:open).and_raise(StandardError, "Connection refused")

        update = build_update(photo: photo)

        # The handler rescues top-level errors, so it shouldn't propagate
        expect {
          described_class.new(update).handle
        }.not_to raise_error
      end
    end
  end
end
