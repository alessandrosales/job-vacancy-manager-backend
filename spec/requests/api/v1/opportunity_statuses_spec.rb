# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Opportunity statuses", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/opportunity-statuses" do
    get "Lists opportunity statuses for the current user" do
      tags "Opportunity statuses"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/opportunity_statuses_list"

        let!(:owner) do
          User.create!(
            name: "Os Owner",
            email: "os-owner@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        before do
          owner.opportunity_statuses.create!(label: "Applied", variant: "secondary", position: 1)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.size).to eq(1)
          expect(data.first["label"]).to eq("Applied")
          expect(data.first["variant"]).to eq("secondary")
        end
      end
    end

    post "Creates opportunity status (scoped to current user)" do
      tags "Opportunity statuses"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/opportunity_status_create_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/opportunity_status"

        let!(:owner) do
          User.create!(
            name: "Os C",
            email: "os-create@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) do
          {
            opportunity_status: {
              label: "Interview",
              description: "On site",
              variant: "outline",
              position: 2
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["label"]).to eq("Interview")
          expect(data["user_id"]).to eq(owner.id)
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "Os Bad",
            email: "os-bad@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { opportunity_status: { label: "", variant: "destructive" } } }

        run_test!
      end
    end
  end

  path "/api/v1/opportunity-statuses/{id}" do
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "Opportunity status UUID"

    get "Fetches opportunity status" do
      tags "Opportunity statuses"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "found" do
        schema "$ref" => "#/components/schemas/opportunity_status"

        let!(:owner) do
          User.create!(
            name: "Os Show",
            email: "os-show@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:opportunity_status) { owner.opportunity_statuses.create!(label: "Offer", variant: "default") }
        let(:id) { opportunity_status.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test!
      end

      response 404, "not found" do
        let!(:owner) do
          User.create!(
            name: "Os 404",
            email: "os-404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Updates opportunity status" do
      tags "Opportunity statuses"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/opportunity_status_update_request" }

      response 200, "updated" do
        schema "$ref" => "#/components/schemas/opportunity_status"

        let!(:owner) do
          User.create!(
            name: "Os Patch",
            email: "os-patch@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:opportunity_status) { owner.opportunity_statuses.create!(label: "Old", variant: "secondary") }
        let(:id) { opportunity_status.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { opportunity_status: { label: "Renamed", variant: "destructive" } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["label"]).to eq("Renamed")
        end
      end
    end

    delete "Deletes opportunity status" do
      tags "Opportunity statuses"
      security [ bearer_auth: [] ]

      response 204, "no content" do
        let!(:owner) do
          User.create!(
            name: "Os Del",
            email: "os-del@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:opportunity_status) { owner.opportunity_statuses.create!(label: "Gone", variant: "outline") }
        let(:id) { opportunity_status.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test! do
          expect(OpportunityStatus.find_by(id: opportunity_status.id)).to be_nil
        end
      end

      response 422, "cannot delete while opportunities reference this status" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "Os Block",
            email: "os-block@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:company) { owner.companies.create!(name: "Co") }
        let(:role) { owner.roles.create!(name: "Dev") }
        let!(:opportunity_status) { owner.opportunity_statuses.create!(label: "In use", variant: "default") }
        let!(:_opportunity) do
          owner.opportunities.create!(
            company: company,
            role: role,
            opportunity_status: opportunity_status,
            interest_level: 3
          )
        end
        let(:id) { opportunity_status.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test!
      end
    end
  end
end

RSpec.describe "API V1 — Opportunity statuses isolation", type: :request do
  it "does not return another user's opportunity status by id" do
    alice = User.create!(name: "A", email: "alice-os@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "bob-os@example.com", password: "password12", password_confirmation: "password12")
    bob_row = bob.opportunity_statuses.create!(label: "Secret", variant: "secondary")

    get api_v1_opportunity_status_path(bob_row), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}" }
    expect(response).to have_http_status(:not_found)
  end
end
