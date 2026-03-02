# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntentRouter do
  include_context "telegram_stub"

  let(:chat_id) { 12345 }

  before do
    ENV["TELEGRAM_BOT_TOKEN"] ||= "test_token"
  end

  describe ".dispatch" do
    context "when intent is todo" do
      let(:result) do
        IntentClassifierService::Result.new(
          intent: "todo",
          confidence: 0.95,
          title: "Buy groceries",
          due_at: Date.current,
          body: "Need to buy groceries today"
        )
      end

      it "creates a Task" do
        expect {
          described_class.dispatch(result, chat_id)
        }.to change(Task, :count).by(1)
      end

      it "sets task attributes" do
        task = described_class.dispatch(result, chat_id)

        expect(task).to be_a(Task)
        expect(task.title).to eq("Buy groceries")
        expect(task.description).to eq("Need to buy groceries today")
      end

      it "sends confirmation via Telegram" do
        described_class.dispatch(result, chat_id)

        expect(WebMock).to have_requested(:post, /api\.telegram\.org/)
      end
    end

    context "when intent is event" do
      let(:result) do
        IntentClassifierService::Result.new(
          intent: "event",
          confidence: 0.9,
          title: "Team meeting",
          due_at: 1.day.from_now,
          body: "Meeting tomorrow at 10"
        )
      end

      it "creates a Document tagged as event" do
        expect {
          described_class.dispatch(result, chat_id)
        }.to change(Document, :count).by(1)

        doc = Document.last
        expect(doc.tags.map(&:name)).to include("event")
      end

      it "auto-tags as telegram" do
        described_class.dispatch(result, chat_id)

        doc = Document.last
        expect(doc.tags.map(&:name)).to include("telegram")
      end
    end

    context "when intent is note" do
      let(:result) do
        IntentClassifierService::Result.new(
          intent: "note",
          confidence: 0.8,
          title: "Random thought",
          due_at: nil,
          body: "Just a random thought"
        )
      end

      it "creates a Document" do
        expect {
          described_class.dispatch(result, chat_id)
        }.to change(Document, :count).by(1)
      end

      it "creates a text block with content" do
        described_class.dispatch(result, chat_id)

        doc = Document.last
        expect(doc.blocks.count).to eq(1)
        expect(doc.blocks.first.block_type).to eq("text")
      end

      it "auto-tags as telegram" do
        described_class.dispatch(result, chat_id)

        doc = Document.last
        expect(doc.tags.map(&:name)).to include("telegram")
      end
    end

    context "when Telegram reply fails" do
      let(:result) do
        IntentClassifierService::Result.new(
          intent: "note",
          confidence: 0.8,
          title: "Test",
          due_at: nil,
          body: "test"
        )
      end

      it "does not raise and still creates the document" do
        stub_request(:post, /api\.telegram\.org/)
          .to_return(status: 500, body: "error")

        expect {
          described_class.dispatch(result, chat_id)
        }.to change(Document, :count).by(1)
      end
    end
  end
end
