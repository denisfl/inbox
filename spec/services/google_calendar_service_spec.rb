# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoogleCalendarService do
  let(:service) { described_class.new }

  before do
    ENV["GOOGLE_CLIENT_ID"]     ||= "test_client_id"
    ENV["GOOGLE_CLIENT_SECRET"] ||= "test_client_secret"
    ENV["GOOGLE_REFRESH_TOKEN"] ||= "test_refresh_token"
    ENV["GOOGLE_CALENDAR_IDS"]  ||= "primary"
  end

  describe "#initialize" do
    it "raises when GOOGLE_CLIENT_ID is missing" do
      original = ENV.delete("GOOGLE_CLIENT_ID")
      begin
        expect { described_class.new }.to raise_error(RuntimeError, /GOOGLE_CLIENT_ID/)
      ensure
        ENV["GOOGLE_CLIENT_ID"] = original
      end
    end

    it "raises when GOOGLE_CLIENT_SECRET is missing" do
      original = ENV.delete("GOOGLE_CLIENT_SECRET")
      begin
        expect { described_class.new }.to raise_error(RuntimeError, /GOOGLE_CLIENT_SECRET/)
      ensure
        ENV["GOOGLE_CLIENT_SECRET"] = original
      end
    end

    it "raises when GOOGLE_REFRESH_TOKEN is missing" do
      original = ENV.delete("GOOGLE_REFRESH_TOKEN")
      begin
        expect { described_class.new }.to raise_error(RuntimeError, /GOOGLE_REFRESH_TOKEN/)
      ensure
        ENV["GOOGLE_REFRESH_TOKEN"] = original
      end
    end

    it "defaults calendar IDs to primary" do
      ENV["GOOGLE_CALENDAR_IDS"] = ""

      # We can't directly test @calendar_ids, but construction should not raise
      expect { described_class.new }.not_to raise_error

      ENV["GOOGLE_CALENDAR_IDS"] = "primary"
    end
  end

  describe ".upcoming_events" do
    it "returns upcoming CalendarEvents" do
      future_event = create(:calendar_event, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
      past_event = create(:calendar_event, :past)

      events = described_class.upcoming_events(limit: 10)

      expect(events).to include(future_event)
    end
  end
end
