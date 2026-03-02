# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoogleCalendarSyncJob, type: :job do
  before do
    ENV["GOOGLE_CLIENT_ID"]     ||= "test_client_id"
    ENV["GOOGLE_CLIENT_SECRET"] ||= "test_client_secret"
    ENV["GOOGLE_REFRESH_TOKEN"] ||= "test_refresh_token"
  end

  describe "#perform" do
    it "calls GoogleCalendarService#sync!" do
      service = instance_double(GoogleCalendarService)
      allow(GoogleCalendarService).to receive(:new).and_return(service)
      allow(service).to receive(:sync!)

      described_class.new.perform

      expect(service).to have_received(:sync!)
    end

    it "re-raises errors for retry" do
      service = instance_double(GoogleCalendarService)
      allow(GoogleCalendarService).to receive(:new).and_return(service)
      allow(service).to receive(:sync!).and_raise(StandardError, "API down")

      expect {
        described_class.new.perform
      }.to raise_error(StandardError, "API down")
    end
  end

  describe "queue" do
    it "is enqueued in the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
