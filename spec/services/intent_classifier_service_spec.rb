# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntentClassifierService do
  include_context "ollama_stub"

  describe ".classify" do
    it "classifies text as note by default" do
      stub_ollama_classify(intent: "note", confidence: 0.9, title: "Test note")

      result = described_class.classify("just a random thought")

      expect(result.intent).to eq("note")
      expect(result.confidence).to eq(0.9)
      expect(result.title).to eq("Test note")
    end

    it "classifies text as todo" do
      stub_ollama_classify(intent: "todo", confidence: 0.95, title: "Buy milk")

      result = described_class.classify("need to buy milk")

      expect(result.intent).to eq("todo")
      expect(result.title).to eq("Buy milk")
    end

    it "classifies text as event" do
      due = 1.day.from_now.iso8601
      stub_ollama_classify(intent: "event", confidence: 0.85, title: "Meeting", due_at: due)

      result = described_class.classify("meeting tomorrow at 10")

      expect(result.intent).to eq("event")
      expect(result.due_at).to be_present
    end

    it "falls back to note for unsupported intents" do
      stub_ollama_classify(intent: "reminder", confidence: 0.9, title: "Reminder")

      result = described_class.classify("remind me later")

      expect(result.intent).to eq("note")
    end

    it "falls back to note when confidence is below threshold" do
      stub_ollama_classify(intent: "todo", confidence: 0.3, title: "Maybe task")

      result = described_class.classify("maybe something")

      expect(result.intent).to eq("note")
    end

    it "falls back to note on API error" do
      stub_ollama_error

      result = described_class.classify("test text")

      expect(result.intent).to eq("note")
      expect(result.confidence).to eq(0.0)
    end

    it "preserves body text" do
      stub_ollama_classify(intent: "note", confidence: 0.9, title: "Test")

      result = described_class.classify("my important message")

      expect(result.body).to eq("my important message")
    end
  end
end
