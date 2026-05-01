# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Skills", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/skills" do
    get "Lists skills for the current user" do
      tags "Skills"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/skills_list"

        let!(:owner) do
          User.create!(
            name: "Sk Owner",
            email: "skills-owner@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        before do
          owner.skills.create!(name: "Ruby", description: "Language")
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.size).to eq(1)
          expect(data.first["name"]).to eq("Ruby")
          expect(data.first["user_id"]).to eq(owner.id)
        end
      end
    end

    post "Creates skill (scoped to current user)" do
      tags "Skills"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/skill_create_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/skill"

        let!(:owner) do
          User.create!(
            name: "Sk2",
            email: "skills-create@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { skill: { name: "PostgreSQL", description: "DB" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["name"]).to eq("PostgreSQL")
          expect(data["user_id"]).to eq(owner.id)
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "Sk3",
            email: "skills-bad@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { skill: { name: "" } } }

        run_test!
      end
    end
  end

  path "/api/v1/skills/{id}" do
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "Skill UUID"

    get "Fetches skill" do
      tags "Skills"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "found" do
        schema "$ref" => "#/components/schemas/skill"

        let!(:owner) do
          User.create!(
            name: "Sk4",
            email: "skills-show@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:skill) { owner.skills.create!(name: "Rails") }
        let(:id) { skill.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test!
      end

      response 404, "not found" do
        let!(:owner) do
          User.create!(
            name: "Sk5",
            email: "skills-404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Updates skill" do
      tags "Skills"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/skill_update_request" }

      response 200, "updated" do
        schema "$ref" => "#/components/schemas/skill"

        let!(:owner) do
          User.create!(
            name: "Sk6",
            email: "skills-patch@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:skill) { owner.skills.create!(name: "Old name") }
        let(:id) { skill.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { skill: { name: "New name", description: "Updated" } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["name"]).to eq("New name")
        end
      end
    end

    delete "Deletes skill" do
      tags "Skills"
      security [ bearer_auth: [] ]

      response 204, "no content" do
        let!(:owner) do
          User.create!(
            name: "Sk7",
            email: "skills-del@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:skill) { owner.skills.create!(name: "Remove me") }
        let(:id) { skill.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test! do
          expect(Skill.find_by(id: skill.id)).to be_nil
        end
      end
    end
  end
end

RSpec.describe "API V1 — Skills isolation", type: :request do
  it "does not return another user's skill by id" do
    alice = User.create!(name: "A", email: "alice-sk@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "bob-sk@example.com", password: "password12", password_confirmation: "password12")
    bob_skill = bob.skills.create!(name: "Secret")

    get api_v1_skill_path(bob_skill), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}" }
    expect(response).to have_http_status(:not_found)
  end
end
