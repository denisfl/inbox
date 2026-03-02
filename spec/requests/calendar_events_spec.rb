# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CalendarEvents", type: :request do
  describe "GET /calendar/events/new" do
    it "returns success" do
      get new_calendar_event_path

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
end
