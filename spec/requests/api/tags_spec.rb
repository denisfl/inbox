# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Tags", type: :request do
  include_context "api_auth"

  let(:headers) { api_headers }

  describe "GET /api/tags" do
    before do
      create(:tag, name: "ruby")
      create(:tag, name: "rails")
      create(:tag, name: "javascript")
    end

    it "returns all tags alphabetically" do
      get "/api/tags", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(3)
      expect(json.map { |t| t["name"] }).to eq(%w[javascript rails ruby])
    end

    it "filters tags by query" do
      get "/api/tags", params: { q: "ru" }, headers: headers

      json = JSON.parse(response.body)
      expect(json.map { |t| t["name"] }).to contain_exactly("ruby")
    end

    it "returns name and color for each tag" do
      get "/api/tags", headers: headers

      json = JSON.parse(response.body)
      expect(json.first).to include("name", "color")
    end

    it "returns 401 without authentication" do
      get "/api/tags"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
