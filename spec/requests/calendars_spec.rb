# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Calendars", type: :request do
  describe "GET /calendar" do
    let!(:event) { create(:calendar_event, :today, title: "Team standup") }

    it "returns success" do
      get calendar_path

      expect(response).to have_http_status(:ok)
    end

    it "defaults to agenda view" do
      get calendar_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Team standup")
    end

    it "supports week view" do
      get calendar_path(view: "week")

      expect(response).to have_http_status(:ok)
    end

    it "supports month view" do
      get calendar_path(view: "month")

      expect(response).to have_http_status(:ok)
    end

    it "supports date parameter" do
      get calendar_path(date: "2026-04-15")

      expect(response).to have_http_status(:ok)
    end

    it "filters by events only" do
      get calendar_path(filter: "events")

      expect(response).to have_http_status(:ok)
    end

    it "filters by notes" do
      get calendar_path(filter: "notes")

      expect(response).to have_http_status(:ok)
    end

    it "filters by tasks" do
      get calendar_path(filter: "tasks")

      expect(response).to have_http_status(:ok)
    end

    it "filters by all" do
      get calendar_path(filter: "all")

      expect(response).to have_http_status(:ok)
    end

    it "week view with date parameter" do
      get calendar_path(view: "week", date: "2026-06-15")

      expect(response).to have_http_status(:ok)
    end

    it "month view with date parameter" do
      get calendar_path(view: "month", date: "2026-06-01")

      expect(response).to have_http_status(:ok)
    end

    it "handles invalid date parameter gracefully" do
      get calendar_path(date: "invalid-date")

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /calendar/widget" do
    it "returns success" do
      get calendar_widget_path

      expect(response).to have_http_status(:ok)
    end
  end
end
