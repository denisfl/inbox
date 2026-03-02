# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::TaskTags", type: :request do
  include_context "api_auth"

  let(:headers) { api_headers }
  let!(:task) { create(:task) }

  describe "POST /api/tasks/:task_id/tags" do
    it "creates and attaches a tag" do
      post "/api/tasks/#{task.id}/tags",
           params: { name: "urgent" }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["tag"]["name"]).to eq("urgent")
      expect(task.reload.tags.map(&:name)).to include("urgent")
    end

    it "does not duplicate tag assignment" do
      tag = create(:tag, name: "work")
      task.tags << tag

      post "/api/tasks/#{task.id}/tags",
           params: { name: "work" }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(task.tags.where(name: "work").count).to eq(1)
    end

    it "returns error for blank name" do
      post "/api/tasks/#{task.id}/tags",
           params: { name: "" }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/tasks/:task_id/tags/:name" do
    let!(:tag) { create(:tag, name: "removeme") }

    before { task.tags << tag }

    it "removes the tag from the task" do
      delete "/api/tasks/#{task.id}/tags/removeme", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(task.reload.tags).not_to include(tag)
    end

    it "returns 404 for unknown tag" do
      delete "/api/tasks/#{task.id}/tags/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
