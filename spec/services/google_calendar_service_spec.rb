# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoogleCalendarService do
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
      expect { described_class.new }.not_to raise_error
      ENV["GOOGLE_CALENDAR_IDS"] = "primary"
    end

    it "supports multiple calendar IDs" do
      ENV["GOOGLE_CALENDAR_IDS"] = "primary, work@group.calendar.google.com"
      expect { described_class.new }.not_to raise_error
      ENV["GOOGLE_CALENDAR_IDS"] = "primary"
    end
  end

  describe "#sync!" do
    let(:service) { described_class.new }
    let(:google_service) { instance_double(Google::Apis::CalendarV3::CalendarService) }
    let(:authorizer) { instance_double(Google::Auth::UserRefreshCredentials) }

    let(:client_options) { double("client_options", :open_timeout_sec= => nil, :send_timeout_sec= => nil, :read_timeout_sec= => nil) }

    before do
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(authorizer)
      allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(google_service)
      allow(google_service).to receive(:authorization=)
      allow(google_service).to receive(:client_options).and_return(client_options)
      # Clear any existing sync tokens
      token_path = Rails.root.join("tmp", "google_sync_token_primary.txt")
      File.delete(token_path) if File.exist?(token_path)
    end

    after do
      # Cleanup sync token files
      token_path = Rails.root.join("tmp", "google_sync_token_primary.txt")
      File.delete(token_path) if File.exist?(token_path)
    end

    it "performs full sync when no sync token exists" do
      event_item = double("event",
        id: "google_event_1",
        summary: "Team standup",
        description: "Daily standup",
        status: "confirmed",
        color_id: nil,
        html_link: "https://calendar.google.com/event/1",
        start: double("start", date: nil, date_time: 1.hour.from_now.iso8601),
        end: double("end", date: nil, date_time: 2.hours.from_now.iso8601)
      )

      result = double("result",
        items: [ event_item ],
        next_sync_token: "sync_token_abc",
        next_page_token: nil
      )

      allow(google_service).to receive(:list_events).and_return(result)

      expect {
        service.sync!
      }.to change(CalendarEvent, :count).by(1)

      event = CalendarEvent.last
      expect(event.title).to eq("Team standup")
      expect(event.source).to eq("google")
      expect(event.google_event_id).to eq("google_event_1")
    end

    it "handles cancelled events" do
      existing = create(:calendar_event, :google, google_event_id: "google_cancel_1")

      cancelled_item = double("event",
        id: "google_cancel_1",
        status: "cancelled"
      )

      result = double("result",
        items: [ cancelled_item ],
        next_sync_token: "sync_token_def",
        next_page_token: nil
      )

      allow(google_service).to receive(:list_events).and_return(result)

      service.sync!

      expect(existing.reload.status).to eq("cancelled")
    end

    it "performs delta sync when sync token exists" do
      # Write a sync token file
      token_path = Rails.root.join("tmp", "google_sync_token_primary.txt")
      File.write(token_path, "existing_sync_token")

      result = double("result",
        items: [],
        next_sync_token: "new_sync_token",
        next_page_token: nil
      )

      allow(google_service).to receive(:list_events)
        .with("primary", sync_token: "existing_sync_token", page_token: nil)
        .and_return(result)

      service.sync!

      expect(File.read(token_path).strip).to eq("new_sync_token")
    end

    it "falls back to full sync on 410 (expired token)" do
      # Write an expired sync token
      token_path = Rails.root.join("tmp", "google_sync_token_primary.txt")
      File.write(token_path, "expired_token")

      # First call (delta) raises 410
      error_410 = Google::Apis::ClientError.new("Gone", status_code: 410)
      allow(google_service).to receive(:list_events)
        .with("primary", sync_token: "expired_token", page_token: nil)
        .and_raise(error_410)

      # Second call (full sync) succeeds
      result = double("result",
        items: [],
        next_sync_token: "fresh_token",
        next_page_token: nil
      )
      allow(google_service).to receive(:list_events)
        .with("primary", hash_including(single_events: true))
        .and_return(result)

      service.sync!

      expect(File.read(token_path).strip).to eq("fresh_token")
    end

    it "re-raises non-410 ClientError during delta sync" do
      # Write a sync token to trigger delta_sync path
      token_path = Rails.root.join("tmp", "google_sync_token_primary.txt")
      File.write(token_path, "valid_token")

      # Delta sync raises a non-410 ClientError (e.g. 403 Forbidden)
      error_403 = Google::Apis::ClientError.new("Forbidden", status_code: 403)
      allow(google_service).to receive(:list_events)
        .with("primary", sync_token: "valid_token", page_token: nil)
        .and_raise(error_403)

      # This should NOT be caught — it should propagate up to the per-calendar rescue
      # which catches non-auth errors and logs them
      expect { service.sync! }.not_to raise_error
    end

    it "handles all-day events" do
      all_day_item = double("event",
        id: "google_allday_1",
        summary: "Holiday",
        description: nil,
        status: "confirmed",
        color_id: nil,
        html_link: nil,
        start: double("start", date: Date.current.to_s, date_time: nil),
        end: double("end", date: (Date.current + 1.day).to_s, date_time: nil)
      )

      result = double("result",
        items: [ all_day_item ],
        next_sync_token: "sync_allday",
        next_page_token: nil
      )

      allow(google_service).to receive(:list_events).and_return(result)

      expect {
        service.sync!
      }.to change(CalendarEvent, :count).by(1)

      event = CalendarEvent.last
      expect(event.all_day).to be true
    end

    it "skips calendar on non-auth API errors" do
      error = Google::Apis::ServerError.new("Internal error")
      allow(google_service).to receive(:list_events).and_raise(error)

      # Should not raise — the error is caught and logged
      expect { service.sync! }.not_to raise_error
    end

    it "re-raises auth errors" do
      error = Google::Apis::AuthorizationError.new("Unauthorized")
      allow(google_service).to receive(:list_events).and_raise(error)

      expect { service.sync! }.to raise_error(Google::Apis::AuthorizationError)
    end

    it "skips events with unparseable times" do
      bad_item = double("event",
        id: "google_badtime_1",
        summary: "Bad time event",
        description: nil,
        status: "confirmed",
        color_id: nil,
        html_link: nil,
        start: double("start", date: nil, date_time: "not-a-time"),
        end: double("end", date: nil, date_time: nil)
      )

      result = double("result",
        items: [ bad_item ],
        next_sync_token: "sync_bad",
        next_page_token: nil
      )

      allow(google_service).to receive(:list_events).and_return(result)

      expect {
        service.sync!
      }.not_to change(CalendarEvent, :count)
    end

    it "handles unexpected errors on individual calendars" do
      error = RuntimeError.new("Something weird")
      allow(google_service).to receive(:list_events).and_raise(error)

      expect { service.sync! }.not_to raise_error
    end

    it "updates existing event on re-sync" do
      existing = create(:calendar_event, :google,
        google_event_id: "google_update_1",
        title: "Old title")

      updated_item = double("event",
        id: "google_update_1",
        summary: "Updated title",
        description: "New description",
        status: "confirmed",
        color_id: "1",
        html_link: "https://calendar.google.com/event/u1",
        start: double("start", date: nil, date_time: 1.hour.from_now.iso8601),
        end: double("end", date: nil, date_time: 2.hours.from_now.iso8601)
      )

      result = double("result",
        items: [ updated_item ],
        next_sync_token: "sync_upd",
        next_page_token: nil
      )

      allow(google_service).to receive(:list_events).and_return(result)

      service.sync!

      existing.reload
      expect(existing.title).to eq("Updated title")
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
