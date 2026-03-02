# frozen_string_literal: true

RSpec.shared_context "api_auth" do
  let(:api_token) { ENV["API_TOKEN"] || "development_token" }
  let(:api_headers) do
    {
      "Content-Type" => "application/json",
      "Authorization" => "Token token=#{api_token}"
    }
  end
end
