require "rails_helper"

RSpec.describe "GET /api/health", type: :request do
  describe "overall health" do
    context "when all services are healthy and backup is ok" do
      before do
        create(:backup_record, status: "completed", started_at: 1.hour.ago, completed_at: 30.minutes.ago, size_bytes: 2048)
        # Stub transcriber health check
        stub_request(:get, /transcriber.*\/health/)
          .to_return(status: 200, body: '{"status":"ok"}')
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("TRANSCRIBER_URL").and_return("http://transcriber:5000")
        allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("test-client-id")
        allow(ENV).to receive(:[]).with("GOOGLE_REFRESH_TOKEN").and_return("test-refresh-token")
      end

      it "returns ok status with services and backup" do
        get "/api/health"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["status"]).to eq("ok")
        expect(json["services"]["database"]).to eq("ok")
        expect(json["services"]["transcriber"]).to eq("ok")
        expect(json["backup"]["status"]).to eq("ok")
      end
    end

    context "when transcriber is unavailable" do
      before do
        stub_request(:get, /transcriber.*\/health/)
          .to_raise(Errno::ECONNREFUSED)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("TRANSCRIBER_URL").and_return("http://transcriber:5000")
        allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
        allow(ENV).to receive(:[]).with("GOOGLE_REFRESH_TOKEN").and_return(nil)
      end

      it "returns degraded status with 200" do
        get "/api/health"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["status"]).to eq("degraded")
        expect(json["services"]["transcriber"]).to eq("unavailable")
        expect(json["services"]["database"]).to eq("ok")
      end
    end

    context "when google calendar is not configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("TRANSCRIBER_URL").and_return(nil)
        allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
        allow(ENV).to receive(:[]).with("GOOGLE_REFRESH_TOKEN").and_return(nil)
      end

      it "reports not_configured for services without credentials" do
        get "/api/health"

        json = response.parsed_body
        expect(json["services"]["google_calendar"]).to eq("not_configured")
        expect(json["services"]["transcriber"]).to eq("not_configured")
      end
    end
  end

  describe "backup status" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("TRANSCRIBER_URL").and_return(nil)
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
      allow(ENV).to receive(:[]).with("GOOGLE_REFRESH_TOKEN").and_return(nil)
    end

    context "when last backup was successful" do
      before do
        create(:backup_record, status: "completed", started_at: 1.hour.ago, completed_at: 30.minutes.ago, size_bytes: 2048)
      end

      it "returns ok backup status" do
        get "/api/health"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["backup"]["status"]).to eq("ok")
        expect(json["backup"]["size_bytes"]).to eq(2048)
        expect(json["backup"]["last_backup_at"]).to be_present
      end
    end

    context "when last backup failed" do
      before do
        create(:backup_record, :failed, started_at: 1.hour.ago)
      end

      it "returns failed status with 503" do
        get "/api/health"

        expect(response).to have_http_status(:service_unavailable)
        json = response.parsed_body
        expect(json["status"]).to eq("degraded")
        expect(json["backup"]["status"]).to eq("failed")
      end
    end

    context "when no backup has ever run" do
      it "returns never_run status with 200" do
        get "/api/health"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["backup"]["status"]).to eq("never_run")
      end
    end
  end
end
