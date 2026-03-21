require "rails_helper"

RSpec.describe ExternalServiceClient do
  let(:client) { described_class.new(:test_service, timeout: 5) }

  describe "#initialize" do
    it "uses provided timeout" do
      expect(client.timeout).to eq(5)
    end

    it "uses ENV timeout when available" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("TELEGRAM_TIMEOUT").and_return("45")
      c = described_class.new(:telegram)
      expect(c.timeout).to eq(45)
    end

    it "uses default timeout per service" do
      c = described_class.new(:transcriber)
      expect(c.timeout).to eq(600)
    end

    it "falls back to 30s for unknown services" do
      c = described_class.new(:unknown)
      expect(c.timeout).to eq(30)
    end
  end

  describe "#get" do
    it "returns response on success" do
      stub_request(:get, "http://example.com/test")
        .to_return(status: 200, body: '{"ok":true}')

      response = client.get("http://example.com/test")
      expect(response.status.code).to eq(200)
    end

    it "logs successful calls at debug level" do
      stub_request(:get, "http://example.com/test")
        .to_return(status: 200, body: "ok")

      expect(Rails.logger).to receive(:tagged).with("[test_service]").and_call_original

      client.get("http://example.com/test")
    end
  end

  describe "#post" do
    it "returns response on success" do
      stub_request(:post, "http://example.com/test")
        .to_return(status: 200, body: '{"ok":true}')

      response = client.post("http://example.com/test", json: { data: 1 })
      expect(response.status.code).to eq(200)
    end
  end

  describe "retry behavior" do
    it "retries on connection refused" do
      stub_request(:get, "http://example.com/test")
        .to_raise(Errno::ECONNREFUSED).then
        .to_return(status: 200, body: "ok")

      allow(client).to receive(:sleep) # Skip actual sleep

      response = client.get("http://example.com/test")
      expect(response.status.code).to eq(200)
    end

    it "retries on 5xx server errors" do
      stub_request(:get, "http://example.com/test")
        .to_return(status: 500, body: "error").then
        .to_return(status: 200, body: "ok")

      allow(client).to receive(:sleep)

      response = client.get("http://example.com/test")
      expect(response.status.code).to eq(200)
    end

    it "raises after exhausting retries" do
      stub_request(:get, "http://example.com/test")
        .to_raise(Errno::ECONNREFUSED)

      allow(client).to receive(:sleep)

      expect { client.get("http://example.com/test") }.to raise_error(Errno::ECONNREFUSED)
    end
  end

  describe "no retry on 4xx" do
    it "does not retry on 400" do
      stub_request(:get, "http://example.com/test")
        .to_return(status: 400, body: "bad request")

      response = client.get("http://example.com/test")
      expect(response.status.code).to eq(400)
      expect(a_request(:get, "http://example.com/test")).to have_been_made.once
    end

    it "does not retry on 404" do
      stub_request(:get, "http://example.com/test")
        .to_return(status: 404, body: "not found")

      response = client.get("http://example.com/test")
      expect(response.status.code).to eq(404)
      expect(a_request(:get, "http://example.com/test")).to have_been_made.once
    end
  end

  describe "429 rate limiting" do
    it "respects Retry-After header" do
      stub_request(:get, "http://example.com/test")
        .to_return(status: 429, headers: { "Retry-After" => "2" }, body: "rate limited").then
        .to_return(status: 200, body: "ok")

      allow(client).to receive(:sleep)

      response = client.get("http://example.com/test")
      expect(response.status.code).to eq(200)
      expect(client).to have_received(:sleep).with(2)
    end

    it "uses 60s default when Retry-After is absent" do
      stub_request(:get, "http://example.com/test")
        .to_return(status: 429, body: "rate limited").then
        .to_return(status: 200, body: "ok")

      allow(client).to receive(:sleep)

      response = client.get("http://example.com/test")
      expect(response.status.code).to eq(200)
      expect(client).to have_received(:sleep).with(60)
    end
  end

  describe "error logging" do
    it "logs failures at error level" do
      stub_request(:get, "http://example.com/test")
        .to_return(status: 400, body: "bad")

      expect(Rails.logger).to receive(:tagged).with("[test_service]").and_call_original

      client.get("http://example.com/test")
    end
  end
end
