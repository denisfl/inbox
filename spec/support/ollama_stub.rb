# frozen_string_literal: true

RSpec.shared_context "ollama_stub" do
  let(:ollama_base_url) { ENV.fetch("OLLAMA_BASE_URL", "http://ollama:11434") }

  def stub_ollama_classify(intent: "note", confidence: 0.9, title: "Test", due_at: nil)
    response_json = { intent: intent, confidence: confidence, title: title, due_at: due_at }.to_json
    stub_request(:post, "#{ollama_base_url}/api/generate")
      .to_return(
        status: 200,
        body: { response: response_json }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_ollama_correction(corrected_text)
    stub_request(:post, "#{ollama_base_url}/api/generate")
      .to_return(
        status: 200,
        body: { response: corrected_text }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_ollama_error
    stub_request(:post, "#{ollama_base_url}/api/generate")
      .to_return(status: 500, body: "Internal Server Error")
  end
end
