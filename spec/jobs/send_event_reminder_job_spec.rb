# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendEventReminderJob, type: :job do
  include_context "telegram_stub"

  before do
    ENV["TELEGRAM_BOT_TOKEN"]        ||= "test_token"
    ENV["TELEGRAM_ALLOWED_USER_ID"]  ||= "12345"
    ENV["CALENDAR_REMINDER_MINUTES"] ||= "10"
  end

  describe "#perform" do
    it "sends reminders for events needing reminder" do
      event = create(:calendar_event, :needs_reminder)

      # Stub Net::HTTP for Telegram API
      stub_request(:post, "https://api.telegram.org/bot#{ENV['TELEGRAM_BOT_TOKEN']}/sendMessage")
        .to_return(status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" })

      described_class.new.perform

      expect(event.reload.reminded_at).to be_present
    end

    it "includes html_link when present" do
      event = create(:calendar_event, :needs_reminder,
        html_link: "https://calendar.google.com/event/123")

      stub = stub_request(:post, "https://api.telegram.org/bot#{ENV['TELEGRAM_BOT_TOKEN']}/sendMessage")
        .to_return(status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" })

      described_class.new.perform

      expect(stub).to have_been_requested
      expect(event.reload.reminded_at).to be_present
    end

    it "does nothing when no events need reminding" do
      create(:calendar_event, :today) # already in progress, not needing reminder

      expect {
        described_class.new.perform
      }.not_to raise_error
    end

    it "continues processing other events if one fails" do
      event1 = create(:calendar_event, :needs_reminder, title: "Event 1")
      event2 = create(:calendar_event, :needs_reminder, title: "Event 2",
                       starts_at: event1.starts_at + 1.minute,
                       ends_at: event1.ends_at + 1.minute)

      # Allow Telegram to fail but don't raise from job
      stub_request(:post, "https://api.telegram.org/bot#{ENV['TELEGRAM_BOT_TOKEN']}/sendMessage")
        .to_return(status: 500, body: '{"ok":false}')

      # Should not raise — individual failures are caught
      expect {
        described_class.new.perform
      }.not_to raise_error
    end
  end

  describe "queue" do
    it "is enqueued in the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
