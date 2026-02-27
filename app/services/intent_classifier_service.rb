# frozen_string_literal: true

class IntentClassifierService
  Result = Struct.new(:intent, :confidence, :title, :due_at, :body, keyword_init: true)

  SUPPORTED_INTENTS = %w[todo event note].freeze
  CONFIDENCE_THRESHOLD = 0.65

  def self.classify(text)
    new.classify(text)
  end

  def classify(text)
    response_body = call_ollama(text)
    parsed = JSON.parse(response_body)

    intent = parsed["intent"].to_s.downcase
    intent = "note" unless SUPPORTED_INTENTS.include?(intent)

    confidence = parsed["confidence"].to_f
    intent = "note" if confidence < CONFIDENCE_THRESHOLD

    Result.new(
      intent: intent,
      confidence: confidence,
      title: parsed["title"].to_s.presence || text.truncate(80),
      due_at: parse_due_at(parsed["due_at"]),
      body: text
    )
  rescue StandardError => e
    Rails.logger.error("IntentClassifier failed: #{e.message}")
    Result.new(intent: "note", confidence: 0.0, title: text.truncate(80), due_at: nil, body: text)
  end

  private

  def call_ollama(text)
    model = ENV.fetch("OLLAMA_INTENT_MODEL", "gemma3:4b")
    base_url = ENV.fetch("OLLAMA_BASE_URL", "http://ollama:11434")
    timeout = ENV.fetch("OLLAMA_INTENT_TIMEOUT", "120").to_i
    today = Time.current.strftime("%Y-%m-%d")

    prompt = <<~PROMPT
      You are an intent classifier for a personal inbox app. Given a user's note or voice transcription, classify it into one of these intents:
      - "todo": user wants to do something ("need to", "buy", "call", "remind me", "не забыть", "купить", "позвонить", "сделать")
      - "event": user is creating a time-bound activity ("meeting", "appointment", "на пятницу", "завтра в 10", "встреча", "созвон")
      - "note": general information, ideas, references, anything else

      Respond with ONLY valid JSON (no markdown, no explanation, no ```json blocks):
      {
        "intent": "todo" | "event" | "note",
        "confidence": 0.0 to 1.0,
        "title": "concise title for the item",
        "due_at": "ISO8601 datetime string or null"
      }

      If intent is "event" and a time is mentioned, extract it as ISO8601 datetime using today's date as reference (today = #{today}).
      If confidence is below #{CONFIDENCE_THRESHOLD}, set intent to "note".

      User input:
      #{text}
    PROMPT

    response = HTTP.timeout(timeout).post(
      "#{base_url}/api/generate",
      json: { model: model, prompt: prompt, stream: false }
    )

    unless response.status.success?
      raise "Ollama intent API returned #{response.status}"
    end

    data = JSON.parse(response.body)
    raw = data["response"].to_s.strip

    # Strip markdown code fences if model wrapped response
    raw = raw.gsub(/\A```(?:json)?\s*|\s*```\z/, "").strip

    raw
  end

  def parse_due_at(value)
    return nil if value.blank? || value == "null"

    Time.parse(value)
  rescue ArgumentError, TypeError
    nil
  end
end
