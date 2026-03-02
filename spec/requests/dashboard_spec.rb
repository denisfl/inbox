# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    it "returns success" do
      get dashboard_path

      expect(response).to have_http_status(:ok)
    end

    it "displays stats" do
      create(:task, :due_today)
      create(:calendar_event, :today)
      create(:document, title: "Recent note")

      get dashboard_path

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

    it "auto-tags note as web" do
      post quick_capture_path, params: { content: "Tagged note", capture_type: "note" }

      doc = Document.last
      expect(doc.tags.map(&:name)).to include("web")
    end
  end
end
