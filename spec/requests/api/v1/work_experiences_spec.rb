# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Work experiences", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/work-experiences" do
    get "Lists work experiences for the current user" do
      tags "WorkExperiences"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/work_experiences_list"

        let!(:owner) do
          User.create!(
            name: "WE Owner",
            email: "workexp-owner@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        before do
          owner.work_experiences.create!(
            title: "Dev",
            company_name: "Acme",
            is_remote: true,
            date_from: Date.new(2020, 1, 1),
            date_to: Date.new(2022, 6, 1)
          )
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.size).to eq(1)
          expect(data.first["company_name"]).to eq("Acme")
          expect(data.first["user_id"]).to eq(owner.id)
          expect(data.first["is_remote"]).to be true
        end
      end
    end

    post "Creates work experience (scoped to current user)" do
      tags "WorkExperiences"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/work_experience_create_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/work_experience"

        let!(:owner) do
          User.create!(
            name: "WE2",
            email: "workexp-create@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) do
          {
            work_experience: {
              title: "Lead",
              company_name: "Globex",
              is_remote: false,
              date_from: "2019-03-01",
              date_to: nil
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["title"]).to eq("Lead")
          expect(data["user_id"]).to eq(owner.id)
          expect(data["is_remote"]).to be false
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "WE3",
            email: "workexp-bad@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { work_experience: { title: "", company_name: "" } } }

        run_test!
      end
    end
  end

  path "/api/v1/work-experiences/{id}" do
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "Work experience UUID"

    get "Fetches work experience" do
      tags "WorkExperiences"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "found" do
        schema "$ref" => "#/components/schemas/work_experience"

        let!(:owner) do
          User.create!(
            name: "WE4",
            email: "workexp-show@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:work_experience) do
          owner.work_experiences.create!(title: "Dev", company_name: "Co", is_remote: true)
        end
        let(:id) { work_experience.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test!
      end

      response 404, "not found" do
        let!(:owner) do
          User.create!(
            name: "WE5",
            email: "workexp-404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Updates work experience" do
      tags "WorkExperiences"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/work_experience_update_request" }

      response 200, "updated" do
        schema "$ref" => "#/components/schemas/work_experience"

        let!(:owner) do
          User.create!(
            name: "WE6",
            email: "workexp-patch@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:work_experience) do
          owner.work_experiences.create!(title: "Old", company_name: "OldCo", is_remote: false)
        end
        let(:id) { work_experience.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) do
          { work_experience: { title: "New", company_name: "NewCo", is_remote: true, date_from: "2021-01-01" } }
        end

        run_test! do |response|
          expect(JSON.parse(response.body)["company_name"]).to eq("NewCo")
        end
      end
    end

    delete "Deletes work experience" do
      tags "WorkExperiences"
      security [ bearer_auth: [] ]

      response 204, "no content" do
        let!(:owner) do
          User.create!(
            name: "WE7",
            email: "workexp-del@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:work_experience) do
          owner.work_experiences.create!(title: "X", company_name: "Y", is_remote: false)
        end
        let(:id) { work_experience.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test! do
          expect(WorkExperience.find_by(id: work_experience.id)).to be_nil
        end
      end
    end
  end
end

RSpec.describe "API V1 — Work experiences isolation", type: :request do
  it "does not return another user's work experience by id" do
    alice = User.create!(name: "A", email: "alice-we@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "bob-we@example.com", password: "password12", password_confirmation: "password12")
    exp = bob.work_experiences.create!(title: "Secret", company_name: "Z", is_remote: false)

    get api_v1_work_experience_path(exp), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}" }
    expect(response).to have_http_status(:not_found)
  end
end
