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
  end

  describe "GET /calendar/widget" do
    it "returns success" do
      get calendar_widget_path

      expect(response).to have_http_status(:ok)
    end
  end
end
