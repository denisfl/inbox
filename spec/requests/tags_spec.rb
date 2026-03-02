# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tags", type: :request do
  describe "GET /tags" do
    let!(:tag1) { create(:tag, name: "alpha") }
    let!(:tag2) { create(:tag, name: "beta") }

    it "returns success" do
      get tags_path

      expect(response).to have_http_status(:ok)
    end

    it "lists all tags" do
      get tags_path

      expect(response.body).to include("alpha", "beta")
    end

    it "searches tags by query" do
      get tags_path(q: "alp")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("alpha")
    end

    it "renders filtered view when tags[] param present" do
      doc = create(:document, title: "Test doc")
      create(:document_tag, document: doc, tag: tag1)

      get tags_path(tags: ["alpha"])

      expect(response).to have_http_status(:ok)
    end

    it "renders filtered view with single tag param" do
      doc = create(:document, title: "Single tag doc")
      create(:document_tag, document: doc, tag: tag1)

      get tags_path(tag: "alpha")

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /tags/:name" do
    let!(:tag) { create(:tag, name: "myproject") }
    let!(:doc) { create(:document, title: "Tagged doc") }
    let!(:task) { create(:task, title: "Tagged task") }

    before do
      create(:document_tag, document: doc, tag: tag)
      create(:task_tag, task: task, tag: tag)
    end

    it "returns success" do
      get tag_path(name: "myproject")

      expect(response).to have_http_status(:ok)
    end

    it "shows documents and tasks for the tag" do
      get tag_path(name: "myproject")

      expect(response.body).to include("Tagged doc")
      expect(response.body).to include("Tagged task")
    end

    it "returns 404 for nonexistent tag" do
      get tag_path(name: "nonexistent")

      expect(response).to have_http_status(:not_found)
    end
  end
end
