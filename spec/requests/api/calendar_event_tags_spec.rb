# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::CalendarEventTags", type: :request do
  include_context "api_auth"

  let(:headers) { api_headers }
  let!(:event) { create(:calendar_event) }

  describe "POST /api/calendar_events/:calendar_event_id/tags" do
    it "creates and attaches a tag" do
      post "/api/calendar_events/#{event.id}/tags",
           params: { name: "meeting" }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["tag"]["name"]).to eq("meeting")
      expect(event.reload.tags.map(&:name)).to include("meeting")
    end

    it "does not duplicate tag assignment" do
      tag = create(:tag, name: "work")
      event.tags << tag

      post "/api/calendar_events/#{event.id}/tags",
           params: { name: "work" }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(event.tags.where(name: "work").count).to eq(1)
    end

    it "returns error for blank name" do
      post "/api/calendar_events/#{event.id}/tags",
           params: { name: "" }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/calendar_events/:calendar_event_id/tags/:name" do
    let!(:tag) { create(:tag, name: "removeme") }

    before { event.tags << tag }

    it "removes the tag from the event" do
      delete "/api/calendar_events/#{event.id}/tags/removeme", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(event.reload.tags).not_to include(tag)
    end

    it "returns 404 for unknown tag" do
      delete "/api/calendar_events/#{event.id}/tags/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
