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
      temp_file = Tempfile.new([ "test", ".ics" ])
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
      temp_file = Tempfile.new([ "bad", ".ics" ])
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

      temp_file = Tempfile.new([ "allday", ".ics" ])
      temp_file.write(ics_content)
      temp_file.rewind

      file = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")

      expect {
        post import_ical_path, params: { ical_file: file }
      }.to change(CalendarEvent, :count).by(1)

      event = CalendarEvent.last
      expect(event.source).to eq("ical")
      expect(event.title).to eq("All day event")
      expect(event.all_day).to eq(true)

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

      temp_file = Tempfile.new([ "dup", ".ics" ])
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

    it "handles ICS with non-standard time format via string fallback" do
      # Create ICS where dtstart is a plain string (hits Time.zone.parse fallback)
      ics_content = <<~ICS
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        DTSTART:20260501T140000
        DTEND:20260501T150000
        SUMMARY:String time event
        UID:string-time-uid@example.com
        END:VEVENT
        END:VCALENDAR
      ICS

      temp_file = Tempfile.new([ "strtime", ".ics" ])
      temp_file.write(ics_content)
      temp_file.rewind

      file = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")

      expect {
        post import_ical_path, params: { ical_file: file }
      }.to change(CalendarEvent, :count).by(1)

      temp_file.close
      temp_file.unlink
    end
  end

  describe "normalize_ical_time" do
    let(:controller) { CalendarEventsController.new }

    it "handles objects responding to to_datetime but not to_time" do
      dt_obj = Object.new
      def dt_obj.to_datetime
        DateTime.new(2026, 5, 1, 14, 0, 0)
      end

      result = controller.send(:normalize_ical_time, dt_obj)

      expect(result).to be_present
    end

    it "handles plain string via Time.zone.parse fallback" do
      result = controller.send(:normalize_ical_time, "2026-05-01 14:00:00")

      expect(result).to be_present
      expect(result).to be_a(ActiveSupport::TimeWithZone)
    end

    it "returns nil for nil input" do
      result = controller.send(:normalize_ical_time, nil)

      expect(result).to be_nil
    end

    it "returns nil for unparseable string" do
      result = controller.send(:normalize_ical_time, "not-a-time")

      expect(result).to be_nil
    end
  end

  describe "importing macOS birthday calendar (RRULE:FREQ=YEARLY)" do
    it "imports birthday events projected to current/next year" do
      # macOS exports birthdays with old DTSTART + RRULE:FREQ=YEARLY
      ics_content = <<~ICS
        BEGIN:VCALENDAR
        CALSCALE:GREGORIAN
        PRODID:-//Apple Inc.//macOS 14.5//EN
        VERSION:2.0
        BEGIN:VEVENT
        CREATED:20260225T173927Z
        DTEND;VALUE=DATE:19840923
        DTSTAMP:20260304T080617Z
        DTSTART;VALUE=DATE:19840922
        RRULE:FREQ=YEARLY
        SUMMARY:Test Birthday Person
        UID:birthday-test-uid-1@example.com
        END:VEVENT
        END:VCALENDAR
      ICS

      temp_file = Tempfile.new([ "birthdays", ".ics" ])
      temp_file.write(ics_content)
      temp_file.rewind

      file = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")

      expect {
        post import_ical_path, params: { ical_file: file }
      }.to change(CalendarEvent, :count).by(1)

      event = CalendarEvent.last
      expect(event.title).to eq("Test Birthday Person")
      expect(event.all_day).to eq(true)
      expect(event.source).to eq("ical")
      # Event should be in current or next year, not 1984
      expect(event.starts_at.year).to be >= Date.current.year
      expect(event.starts_at.month).to eq(9)
      expect(event.starts_at.day).to eq(22)
      # Description should include birth year info
      expect(event.description.to_plain_text).to include("Born: 1984")

      temp_file.close
      temp_file.unlink
    end

    it "imports multiple birthday events from one calendar" do
      ics_content = <<~ICS
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:19840922
        DTEND;VALUE=DATE:19840923
        RRULE:FREQ=YEARLY
        SUMMARY:Person A
        UID:bday-a@example.com
        END:VEVENT
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:19900305
        DTEND;VALUE=DATE:19900306
        RRULE:FREQ=YEARLY
        SUMMARY:Person B
        UID:bday-b@example.com
        END:VEVENT
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:16040228
        DTEND;VALUE=DATE:16040229
        RRULE:FREQ=YEARLY
        SUMMARY:Person C (no birth year)
        UID:bday-c@example.com
        END:VEVENT
        END:VCALENDAR
      ICS

      temp_file = Tempfile.new([ "multi_bday", ".ics" ])
      temp_file.write(ics_content)
      temp_file.rewind

      file = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")

      expect {
        post import_ical_path, params: { ical_file: file }
      }.to change(CalendarEvent, :count).by(3)

      events = CalendarEvent.order(:starts_at).last(3)
      events.each do |e|
        expect(e.starts_at.year).to be >= Date.current.year
        expect(e.all_day).to eq(true)
      end

      # Person C (year 1604) should NOT have birth year in description
      person_c = events.find { |e| e.title.include?("Person C") }
      expect(person_c.description.to_plain_text).to be_blank

      # Person A (year 1984) SHOULD have birth year
      person_a = events.find { |e| e.title.include?("Person A") }
      expect(person_a.description.to_plain_text).to include("Born: 1984")

      temp_file.close
      temp_file.unlink
    end
  end

  describe "importing timezone-aware events" do
    it "imports Microsoft Exchange meeting with TZID" do
      ics_content = <<~ICS
        BEGIN:VCALENDAR
        METHOD:REQUEST
        PRODID:Microsoft Exchange Server 2010
        VERSION:2.0
        BEGIN:VTIMEZONE
        TZID:Central Europe Standard Time
        BEGIN:STANDARD
        DTSTART:16010101T030000
        TZOFFSETFROM:+0200
        TZOFFSETTO:+0100
        RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=10
        END:STANDARD
        BEGIN:DAYLIGHT
        DTSTART:16010101T020000
        TZOFFSETFROM:+0100
        TZOFFSETTO:+0200
        RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=3
        END:DAYLIGHT
        END:VTIMEZONE
        BEGIN:VEVENT
        DTSTART;TZID=Central Europe Standard Time:20260225T113000
        DTEND;TZID=Central Europe Standard Time:20260225T115000
        SUMMARY:Team Call
        UID:ms-exchange-test@example.com
        STATUS:CONFIRMED
        LOCATION:Microsoft Teams Meeting
        END:VEVENT
        END:VCALENDAR
      ICS

      temp_file = Tempfile.new([ "exchange", ".ics" ])
      temp_file.write(ics_content)
      temp_file.rewind

      file = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")

      expect {
        post import_ical_path, params: { ical_file: file }
      }.to change(CalendarEvent, :count).by(1)

      event = CalendarEvent.last
      expect(event.title).to eq("Team Call")
      expect(event.all_day).to eq(false)
      expect(event.starts_at).to be_present
      expect(event.ends_at).to be_present
      expect(event.source).to eq("ical")

      temp_file.close
      temp_file.unlink
    end

    it "imports Google Calendar invite with TZID" do
      ics_content = <<~ICS
        BEGIN:VCALENDAR
        PRODID:-//Google Inc//Google Calendar 70.9054//EN
        VERSION:2.0
        BEGIN:VTIMEZONE
        TZID:Asia/Tbilisi
        BEGIN:STANDARD
        TZOFFSETFROM:+0400
        TZOFFSETTO:+0400
        TZNAME:GMT+4
        DTSTART:19700101T000000
        END:STANDARD
        END:VTIMEZONE
        BEGIN:VEVENT
        DTSTART;TZID=Asia/Tbilisi:20260224T140000
        DTEND;TZID=Asia/Tbilisi:20260224T153000
        SUMMARY:Interview Call
        UID:google-cal-test@example.com
        STATUS:CONFIRMED
        END:VEVENT
        END:VCALENDAR
      ICS

      temp_file = Tempfile.new([ "gcal", ".ics" ])
      temp_file.write(ics_content)
      temp_file.rewind

      file = Rack::Test::UploadedFile.new(temp_file.path, "text/calendar")

      expect {
        post import_ical_path, params: { ical_file: file }
      }.to change(CalendarEvent, :count).by(1)

      event = CalendarEvent.last
      expect(event.title).to eq("Interview Call")
      expect(event.all_day).to eq(false)
      expect(event.source).to eq("ical")

      temp_file.close
      temp_file.unlink
    end
  end

  describe "ical_date_only? helper" do
    let(:controller) { CalendarEventsController.new }

    it "returns true for Icalendar::Values::Date" do
      require "icalendar"
      dt = Icalendar::Values::Date.new("20260420")
      expect(controller.send(:ical_date_only?, dt)).to eq(true)
    end

    it "returns false for Icalendar::Values::DateTime" do
      require "icalendar"
      dt = Icalendar::Values::DateTime.new("20260420T100000Z")
      expect(controller.send(:ical_date_only?, dt)).to eq(false)
    end

    it "returns false for nil" do
      expect(controller.send(:ical_date_only?, nil)).to eq(false)
    end
  end
end
