# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v1/dashboard", type: :request do
  it "returns 401 without Authorization" do
    get "/api/v1/dashboard"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns aggregates and lists for the current user" do
    owner = User.create!(
      name: "Dash User",
      email: "dash-user@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    company = owner.companies.create!(name: "Acme Co")
    role = owner.roles.create!(name: "Engineer")
    status = owner.opportunity_statuses.create!(label: "Applied", variant: "secondary")
    owner.opportunities.create!(
      company: company,
      role: role,
      opportunity_status: status,
      interest_level: 4,
      description: "Dream job"
    )

    get "/api/v1/dashboard",
      headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(owner)}" }

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json).to include(
      "pie_by_status",
      "created_by_weekday",
      "trend_by_week",
      "status_series",
      "recent_opportunities",
      "top_opportunities",
      "reference_lists"
    )
    expect(json["pie_by_status"].first["count"]).to eq(1)
    expect(json["recent_opportunities"].first["company_name"]).to eq("Acme Co")
    expect(json["recent_opportunities"].first["role_name"]).to eq("Engineer")
    expect(json["reference_lists"]["companies"].first["name"]).to eq("Acme Co")
  end
end
