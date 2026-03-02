# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::DocumentTags", type: :request do
  include_context "api_auth"

  let(:headers) { api_headers }
  let!(:document) { create(:document) }

  describe "POST /api/documents/:document_id/tags" do
    it "creates and attaches a new tag" do
      post "/api/documents/#{document.id}/tags",
           params: { name: "important" }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["tag"]["name"]).to eq("important")
      expect(document.reload.tags.map(&:name)).to include("important")
    end

    it "reuses existing tag" do
      existing_tag = create(:tag, name: "existing")

      expect {
        post "/api/documents/#{document.id}/tags",
             params: { name: "existing" }.to_json,
             headers: headers
      }.not_to change(Tag, :count)

      expect(document.reload.tags).to include(existing_tag)
    end

    it "does not duplicate tag assignment" do
      tag = create(:tag, name: "unique")
      document.tags << tag

      post "/api/documents/#{document.id}/tags",
           params: { name: "unique" }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(document.tags.where(name: "unique").count).to eq(1)
    end

    it "returns error for blank name" do
      post "/api/documents/#{document.id}/tags",
           params: { name: "" }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 401 without auth" do
      post "/api/documents/#{document.id}/tags",
           params: { name: "test" }.to_json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/documents/:document_id/tags/:name" do
    let!(:tag) { create(:tag, name: "removeme") }

    before { document.tags << tag }

    it "removes the tag from the document" do
      delete "/api/documents/#{document.id}/tags/removeme", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(document.reload.tags).not_to include(tag)
    end

    it "returns 404 for unknown tag" do
      delete "/api/documents/#{document.id}/tags/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
