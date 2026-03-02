# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CalendarEvents", type: :request do
  describe "GET /calendar/events/new" do
    it "returns success" do
      get new_calendar_event_path

      expect(response).to have_http_status(:ok)
    end

    it "uses params[:date] for default date" do
      get new_calendar_event_path(date: "2026-06-15")

      expect(response).to have_http_status(:ok)
    end

    it "handles invalid params[:date] gracefully" do
      get new_calendar_event_path(date: "not-a-date")

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /calendar/events" do
    it "creates an event with valid params" do
      expect {
        post calendar_events_path, params: {
          calendar_event: {
            title: "New meeting",
            starts_at: 1.hour.from_now,
            ends_at: 2.hours.from_now
          }
        }
      }.to change(CalendarEvent, :count).by(1)

      expect(response).to redirect_to(calendar_path(date: CalendarEvent.last.starts_at.to_date))
    end

    it "sets source to manual and status to confirmed" do
      post calendar_events_path, params: {
        calendar_event: {
          title: "Manual event",
          starts_at: 1.hour.from_now,
          ends_at: 2.hours.from_now
        }
      }

      event = CalendarEvent.last
      expect(event.source).to eq("manual")
      expect(event.status).to eq("confirmed")
    end

    it "renders new on invalid params" do
      post calendar_events_path, params: {
        calendar_event: { title: "" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /calendar/events/:id/edit" do
    it "returns success for manual event" do
      event = create(:calendar_event)

      get edit_calendar_event_path(event)

      expect(response).to have_http_status(:ok)
    end

    it "redirects for Google event" do
      event = create(:calendar_event, :google)

      get edit_calendar_event_path(event)

      expect(response).to redirect_to(calendar_path)
    end
  end

  describe "PATCH /calendar/events/:id" do
    let(:event) { create(:calendar_event, title: "Old title") }

    it "updates a manual event" do
      patch calendar_event_path(event), params: {
        calendar_event: { title: "Updated title" }
      }

      expect(response).to have_http_status(:redirect)
      expect(event.reload.title).to eq("Updated title")
    end

    it "redirects for Google event" do
      google_event = create(:calendar_event, :google)

      patch calendar_event_path(google_event), params: {
        calendar_event: { title: "Hacked" }
      }

      expect(response).to redirect_to(calendar_path)
      expect(google_event.reload.title).not_to eq("Hacked")
    end

    it "renders edit on invalid params" do
      patch calendar_event_path(event), params: {
        calendar_event: { title: "" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /calendar/events/:id" do
    it "deletes a manual event" do
      event = create(:calendar_event)

      expect {
        delete calendar_event_path(event)
      }.to change(CalendarEvent, :count).by(-1)

      expect(response).to redirect_to(calendar_path)
    end

    it "does not delete a Google event" do
      google_event = create(:calendar_event, :google)

      expect {
        delete calendar_event_path(google_event)
      }.not_to change(CalendarEvent, :count)

      expect(response).to redirect_to(calendar_path)
    end
  end

  describe "POST /calendar/import" do
    it "imports events from valid ICS file" do
      ics_content = <<~ICS
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        DTSTART:20260415T100000Z
        DTEND:20260415T110000Z
        SUMMARY:Imported event
        UID:test-uid-123@example.com
        END:VEVENT
        END:VCALENDAR
      ICS

      # Create a real temp file for upload
      temp_file = Tempfile.new(["test", ".ics"])
      temp_file.write(ics_content)
      temp_file.rewind

      file = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")

      expect {
        post import_ical_path, params: { ical_file: file }
      }.to change(CalendarEvent, :count).by(1)

      expect(response).to redirect_to(calendar_path)

      temp_file.close
      temp_file.unlink
    end

    it "redirects with alert when no file selected" do
      post import_ical_path

      expect(response).to redirect_to(calendar_path)
    end

    it "rejects non-ICS files" do
      file = fixture_file_upload(
        Rails.root.join("spec", "fixtures", "files", "test_upload.txt"),
        "text/plain"
      )

      post import_ical_path, params: { ical_file: file }

      expect(response).to redirect_to(calendar_path)
    end

    it "handles invalid ICS content gracefully" do
      temp_file = Tempfile.new(["bad", ".ics"])
      temp_file.write("not valid ical content")
      temp_file.rewind

      file = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")

      post import_ical_path, params: { ical_file: file }

      expect(response).to redirect_to(calendar_path)
      expect(flash[:alert] || flash[:notice]).to be_present

      temp_file.close
      temp_file.unlink
    end

    it "imports events with Date-only dtstart (all-day)" do
      ics_content = <<~ICS
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20260420
        DTEND;VALUE=DATE:20260421
        SUMMARY:All day event
        UID:allday-uid@example.com
        END:VEVENT
        END:VCALENDAR
      ICS

      temp_file = Tempfile.new(["allday", ".ics"])
      temp_file.write(ics_content)
      temp_file.rewind

      file = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")

      expect {
        post import_ical_path, params: { ical_file: file }
      }.to change(CalendarEvent, :count).by(1)

      event = CalendarEvent.last
      expect(event.all_day).to be true
      expect(event.source).to eq("ical")

      temp_file.close
      temp_file.unlink
    end

    it "skips duplicate ical imports" do
      # First import
      ics_content = <<~ICS
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        DTSTART:20260415T100000Z
        DTEND:20260415T110000Z
        SUMMARY:Duplicate event
        UID:dup-uid@example.com
        END:VEVENT
        END:VCALENDAR
      ICS

      temp_file = Tempfile.new(["dup", ".ics"])
      temp_file.write(ics_content)
      temp_file.rewind

      file = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")
      post import_ical_path, params: { ical_file: file }

      temp_file.rewind
      file2 = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")

      expect {
        post import_ical_path, params: { ical_file: file2 }
      }.not_to change(CalendarEvent, :count)

      temp_file.close
      temp_file.unlink
    end
  end
end
