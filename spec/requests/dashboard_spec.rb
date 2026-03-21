# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    it "returns success" do
      get dashboard_path

      expect(response).to have_http_status(:ok)
    end

    it "displays stats with tasks and events" do
      create(:task, :due_today)
      create(:calendar_event, :today)
      create(:document, title: "Recent note")

      get dashboard_path

      expect(response).to have_http_status(:ok)
    end

    it "builds activity feed from recent documents" do
      create(:document, title: "Feed doc", created_at: 1.day.ago)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Feed doc")
    end

    it "builds activity feed from completed tasks" do
      create(:task, :completed, title: "Done task", completed_at: 1.hour.ago)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Done task")
    end

    it "shows upcoming events" do
      create(:calendar_event, :tomorrow, title: "Tomorrow meeting")

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tomorrow meeting")
    end

    it "supports cal_month parameter for mini calendar" do
      get dashboard_path(cal_month: "2026-06")

      expect(response).to have_http_status(:ok)
    end

    it "shows overdue tasks count" do
      create(:task, :overdue, title: "Overdue item")

      get dashboard_path

      expect(response).to have_http_status(:ok)
    end

    it "shows busy day greeting when many tasks and events" do
      6.times { create(:task, :due_today) }
      4.times { create(:calendar_event, :today) }

      get dashboard_path

      expect(response).to have_http_status(:ok)
    end

    it "includes google calendar sync activity" do
      create(:calendar_event, :google, synced_at: 1.hour.ago)

      get dashboard_path

      expect(response).to have_http_status(:ok)
    end

    it "includes telegram-tagged documents in activity feed" do
      doc = create(:document, title: "TG note", created_at: 1.day.ago)
      tag = create(:tag, name: "telegram")
      create(:document_tag, document: doc, tag: tag)

      get dashboard_path

      expect(response).to have_http_status(:ok)
    end

    it "includes audio-tagged documents in activity feed" do
      doc = create(:document, title: "Audio note", created_at: 1.day.ago)
      tag = create(:tag, name: "audio")
      create(:document_tag, document: doc, tag: tag)

      get dashboard_path

      expect(response).to have_http_status(:ok)
    end

    it "includes recently created tasks in activity feed" do
      create(:task, title: "New task", created_at: 1.hour.ago)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New task")
    end

    it "includes recently started events in activity feed" do
      create(:calendar_event, title: "Started event", starts_at: 30.minutes.ago, ends_at: 30.minutes.from_now)

      get dashboard_path

      expect(response).to have_http_status(:ok)
    end

    it "builds activity feed with telegram-tagged document using icon_for_tags" do
      travel_to 1.hour.ago do
        doc = create(:document, title: "TG activity test")
        tag = create(:tag, name: "telegram")
        create(:document_tag, document: doc, tag: tag)
      end

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Telegram")
    end

    it "builds activity feed with audio-tagged document using icon_for_tags" do
      travel_to 1.hour.ago do
        doc = create(:document, title: "Voice activity test")
        tag = create(:tag, name: "audio")
        create(:document_tag, document: doc, tag: tag)
      end

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Voice note")
    end
  end

  describe "GET / (root)" do
    it "renders the dashboard" do
      get root_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /quick_capture" do
    it "creates a note and redirects to edit" do
      expect {
        post quick_capture_path, params: { content: "Quick note text", capture_type: "note" }
      }.to change(Document, :count).by(1)

      expect(response).to redirect_to(edit_document_path(Document.last))
    end

    it "creates a task" do
      expect {
        post quick_capture_path, params: { content: "Buy groceries", capture_type: "task" }
      }.to change(Task, :count).by(1)

      expect(response).to redirect_to(root_path)
    end

    it "creates an event" do
      expect {
        post quick_capture_path, params: { content: "Team meeting", capture_type: "event" }
      }.to change(CalendarEvent, :count).by(1)

      expect(response).to redirect_to(root_path)
    end

    it "redirects with alert for blank content" do
      post quick_capture_path, params: { content: "", capture_type: "note" }

      expect(response).to redirect_to(root_path)
    end

    it "redirects with alert for unknown type" do
      post quick_capture_path, params: { content: "test", capture_type: "unknown" }

      expect(response).to redirect_to(root_path)
    end

    it "does not auto-tag note as web" do
      post quick_capture_path, params: { content: "Tagged note", capture_type: "note" }

      doc = Document.last
      expect(doc.tags.map(&:name)).not_to include("web")
    end
  end
end
