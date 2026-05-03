# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 — Languages" do
  let(:user) do
    User.create!(
      name: "Lang User",
      email: "lang-user@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
  end
  let(:auth_headers) { { "Authorization" => "Bearer #{User::JwtIssuer.encode(user)}" } }

  describe "GET /api/v1/languages" do
    it "returns languages for the current user" do
      user.languages.create!(name: "English", level: "native")
      get "/api/v1/languages", params: { paginated: false }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data).to be_an(Array)
      expect(data.first["name"]).to eq("English")
      expect(data.first["level"]).to eq("native")
    end
  end

  describe "POST /api/v1/languages" do
    it "creates a language" do
      post "/api/v1/languages",
        params: { language: { name: "Portuguese", level: "advanced" } },
        headers: auth_headers.merge("Content-Type" => "application/json"),
        as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Portuguese")
      expect(body["level"]).to eq("advanced")
    end

    it "returns 422 for invalid level" do
      post "/api/v1/languages",
        params: { language: { name: "X", level: "expert" } },
        headers: auth_headers.merge("Content-Type" => "application/json"),
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
