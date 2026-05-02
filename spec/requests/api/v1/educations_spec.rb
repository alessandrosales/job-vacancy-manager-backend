# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Educations", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/educations" do
    get "Lists educations for the current user (paginated by default)" do
      tags "Educations"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1 },
        description: "Page number (default 1)."
      parameter name: :per_page, in: :query, required: false, schema: { type: :integer, minimum: 1, maximum: 100 },
        description: "Items per page (default 25, max 100)."
      parameter name: :paginated, in: :query, required: false, schema: { type: :string },
        description: "Send `false`/`0`/`no` to receive the legacy bare array response."

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/paginated_educations"

        let!(:owner) do
          User.create!(
            name: "Edu Owner",
            email: "edu-owner@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:page) { nil }
        let(:per_page) { nil }
        let(:paginated) { nil }

        before do
          owner.educations.create!(
            institution_name: "Uni X",
            degree: "BS",
            field_of_study: "CS",
            date_from: Date.new(2015, 9, 1),
            date_to: Date.new(2019, 6, 30)
          )
        end

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload).to include("data", "meta")
          expect(payload["data"].size).to eq(1)
          expect(payload["data"].first["institution_name"]).to eq("Uni X")
          expect(payload["data"].first["user_id"]).to eq(owner.id)
        end
      end
    end

    post "Creates education (scoped to current user)" do
      tags "Educations"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/education_create_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/education"

        let!(:owner) do
          User.create!(
            name: "Edu C",
            email: "edu-create@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) do
          {
            education: {
              institution_name: "Institute Y",
              degree: "MSc",
              field_of_study: "Data",
              date_from: "2020-03-01",
              date_to: "2022-02-28"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["institution_name"]).to eq("Institute Y")
          expect(data["degree"]).to eq("MSc")
          expect(data["user_id"]).to eq(owner.id)
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "Edu Bad",
            email: "edu-bad@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { education: { institution_name: "" } } }

        run_test!
      end
    end
  end

  path "/api/v1/educations/{id}" do
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "Education UUID"

    get "Fetches education" do
      tags "Educations"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "found" do
        schema "$ref" => "#/components/schemas/education"

        let!(:owner) do
          User.create!(
            name: "Edu Show",
            email: "edu-show@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:education) { owner.educations.create!(institution_name: "School Z") }
        let(:id) { education.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test!
      end

      response 404, "not found" do
        let!(:owner) do
          User.create!(
            name: "Edu 404",
            email: "edu-404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Updates education" do
      tags "Educations"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/education_update_request" }

      response 200, "updated" do
        schema "$ref" => "#/components/schemas/education"

        let!(:owner) do
          User.create!(
            name: "Edu Patch",
            email: "edu-patch@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:education) { owner.educations.create!(institution_name: "Old Uni") }
        let(:id) { education.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { education: { institution_name: "New Uni", degree: "PhD" } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["institution_name"]).to eq("New Uni")
          expect(JSON.parse(response.body)["degree"]).to eq("PhD")
        end
      end
    end

    delete "Deletes education" do
      tags "Educations"
      security [ bearer_auth: [] ]

      response 204, "no content" do
        let!(:owner) do
          User.create!(
            name: "Edu Del",
            email: "edu-del@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:education) { owner.educations.create!(institution_name: "Gone") }
        let(:id) { education.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test! do
          expect(Education.find_by(id: education.id)).to be_nil
        end
      end
    end
  end
end

RSpec.describe "API V1 — Educations pagination", type: :request do
  it_behaves_like "paginated index", path: "/api/v1/educations" do
    let!(:owner) do
      User.create!(
        name: "Pag", email: "edu-pag@example.com",
        password: "password12", password_confirmation: "password12"
      )
    end
    let(:authorization_header) { "Bearer #{User::JwtIssuer.encode(owner)}" }
    let(:expected_total) { 3 }

    before do
      3.times { |i| owner.educations.create!(institution_name: "Inst#{i}") }
    end
  end
end

RSpec.describe "API V1 — Educations isolation", type: :request do
  it "does not return another user's education by id" do
    alice = User.create!(name: "A", email: "alice-edu@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "bob-edu@example.com", password: "password12", password_confirmation: "password12")
    bob_edu = bob.educations.create!(institution_name: "Secret Uni")

    get api_v1_education_path(bob_edu), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}" }
    expect(response).to have_http_status(:not_found)
  end
end
