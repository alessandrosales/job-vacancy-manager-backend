# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Opportunities", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/opportunities" do
    get "Lists opportunities for the current user" do
      tags "Opportunities"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/opportunities_list"

        let!(:owner) do
          User.create!(
            name: "Op Owner",
            email: "op-owner@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:company) { owner.companies.create!(name: "Acme") }
        let(:role) { owner.roles.create!(name: "Staff") }
        let(:status) { owner.opportunity_statuses.create!(label: "New", variant: "secondary") }

        before do
          owner.opportunities.create!(
            company: company,
            role: role,
            opportunity_status: status,
            interest_level: 4,
            description: "Nice gig"
          )
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.size).to eq(1)
          expect(data.first["description"]).to eq("Nice gig")
          expect(data.first["company_id"]).to eq(company.id)
        end
      end
    end

    post "Creates opportunity (scoped to current user)" do
      tags "Opportunities"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/opportunity_create_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/opportunity"

        let!(:owner) do
          User.create!(
            name: "Op C",
            email: "op-create@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:company) { owner.companies.create!(name: "Globex") }
        let(:role) { owner.roles.create!(name: "Lead") }
        let(:status) { owner.opportunity_statuses.create!(label: "Screen", variant: "outline") }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) do
          {
            opportunity: {
              company_id: company.id,
              role_id: role.id,
              status_id: status.id,
              interest_level: 2,
              url: "https://jobs.example.com/1",
              hourly_rate: 120.5,
              annual_salary: nil
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["user_id"]).to eq(owner.id)
          expect(data["status_id"]).to eq(status.id)
          expect(data["interest_level"]).to eq(2)
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "Op Bad",
            email: "op-bad@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:company) { owner.companies.create!(name: "Solo") }
        let(:role) { owner.roles.create!(name: "R") }
        let(:status) { owner.opportunity_statuses.create!(label: "S", variant: "default") }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) do
          {
            opportunity: {
              company_id: company.id,
              role_id: role.id,
              status_id: status.id,
              interest_level: 99
            }
          }
        end

        run_test!
      end
    end
  end

  path "/api/v1/opportunities/{id}" do
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "Opportunity UUID"

    get "Fetches opportunity" do
      tags "Opportunities"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "found" do
        schema "$ref" => "#/components/schemas/opportunity"

        let!(:owner) do
          User.create!(
            name: "Op Show",
            email: "op-show@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:company) { owner.companies.create!(name: "Co") }
        let(:role) { owner.roles.create!(name: "Job") }
        let(:status) { owner.opportunity_statuses.create!(label: "St", variant: "destructive") }
        let(:opportunity) do
          owner.opportunities.create!(company: company, role: role, opportunity_status: status, interest_level: 0)
        end
        let(:id) { opportunity.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test!
      end

      response 404, "not found" do
        let!(:owner) do
          User.create!(
            name: "Op 404",
            email: "op-404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Updates opportunity" do
      tags "Opportunities"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/opportunity_update_request" }

      response 200, "updated" do
        schema "$ref" => "#/components/schemas/opportunity"

        let!(:owner) do
          User.create!(
            name: "Op Patch",
            email: "op-patch@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:company) { owner.companies.create!(name: "C1") }
        let(:role) { owner.roles.create!(name: "R1") }
        let(:status) { owner.opportunity_statuses.create!(label: "L1", variant: "secondary") }
        let(:opportunity) do
          owner.opportunities.create!(company: company, role: role, opportunity_status: status, interest_level: 1)
        end
        let(:id) { opportunity.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { opportunity: { interest_level: 5, description: "Updated" } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["interest_level"]).to eq(5)
          expect(JSON.parse(response.body)["description"]).to eq("Updated")
        end
      end
    end

    delete "Deletes opportunity" do
      tags "Opportunities"
      security [ bearer_auth: [] ]

      response 204, "no content" do
        let!(:owner) do
          User.create!(
            name: "Op Del",
            email: "op-del@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:company) { owner.companies.create!(name: "X") }
        let(:role) { owner.roles.create!(name: "Y") }
        let(:status) { owner.opportunity_statuses.create!(label: "Z", variant: "default") }
        let!(:opportunity) do
          owner.opportunities.create!(company: company, role: role, opportunity_status: status, interest_level: 0)
        end
        let(:id) { opportunity.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test! do
          expect(Opportunity.find_by(id: opportunity.id)).to be_nil
        end
      end
    end
  end
end

RSpec.describe "API V1 — Opportunities isolation", type: :request do
  it "does not return another user's opportunity by id" do
    alice = User.create!(name: "A", email: "alice-op@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "bob-op@example.com", password: "password12", password_confirmation: "password12")
    company = bob.companies.create!(name: "B Co")
    role = bob.roles.create!(name: "B Role")
    status = bob.opportunity_statuses.create!(label: "B St", variant: "outline")
    opp = bob.opportunities.create!(company: company, role: role, opportunity_status: status, interest_level: 1)

    get api_v1_opportunity_path(opp), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}" }
    expect(response).to have_http_status(:not_found)
  end
end
