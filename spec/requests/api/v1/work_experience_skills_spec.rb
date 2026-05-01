# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Work experience skills (sync)", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/work_experiences/{work_experience_id}/skills" do
    parameter name: :work_experience_id, in: :path, type: :string, format: :uuid,
      description: "Work experience UUID"

    patch "Syncs skills (full replacement; empty array clears)" do
      tags "WorkExperienceSkills"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/work_experience_skill_sync_request" }

      response 200, "updated list" do
        schema "$ref" => "#/components/schemas/skills_linked_to_work_experience"

        let!(:owner) do
          User.create!(
            name: "WES Owner",
            email: "wes-sync@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:skill_a) { owner.skills.create!(name: "Ruby") }
        let!(:skill_b) { owner.skills.create!(name: "SQL") }
        let!(:work_experience) do
          owner.work_experiences.create!(title: "Dev", company_name: "Co", is_remote: true)
        end
        let(:work_experience_id) { work_experience.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { work_experience_skill: { skill_ids: [ skill_b.id, skill_a.id ] } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.map { |h| h["id"] }).to eq([ skill_b.id, skill_a.id ])
        end
      end

      response 200, "clears all links" do
        schema "$ref" => "#/components/schemas/skills_linked_to_work_experience"

        let!(:owner) do
          User.create!(
            name: "WES Clear",
            email: "wes-clear@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:skill) { owner.skills.create!(name: "Go") }
        let!(:work_experience) do
          owner.work_experiences.create!(title: "Eng", company_name: "X", is_remote: false)
        end
        let(:work_experience_id) { work_experience.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { work_experience_skill: { skill_ids: [] } } }

        before do
          work_experience.work_experience_skills.create!(skill_id: skill.id, user_id: owner.id)
        end

        run_test! do |response|
          expect(JSON.parse(response.body)).to eq([])
        end
      end

      response 422, "unknown skill id for user" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "WES422",
            email: "wes-422@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:other) do
          User.create!(
            name: "Other",
            email: "wes-other@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:foreign_skill) { other.skills.create!(name: "Hidden") }
        let!(:work_experience) do
          owner.work_experiences.create!(title: "Job", company_name: "Y", is_remote: false)
        end
        let(:work_experience_id) { work_experience.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { work_experience_skill: { skill_ids: [ foreign_skill.id ] } } }

        run_test!
      end

      response 404, "work experience not found" do
        let!(:owner) do
          User.create!(
            name: "WES404",
            email: "wes-we404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:work_experience_id) { SecureRandom.uuid }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { work_experience_skill: { skill_ids: [] } } }

        run_test!
      end
    end
  end
end

RSpec.describe "API V1 — Work experience skills isolation", type: :request do
  it "returns 404 when syncing skills on another user's work experience" do
    alice = User.create!(name: "A", email: "alice-wesync@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "bob-wesync@example.com", password: "password12", password_confirmation: "password12")
    bob_skill = bob.skills.create!(name: "S")
    bob_we = bob.work_experiences.create!(title: "Bob job", company_name: "B", is_remote: false)

    patch api_v1_work_experience_skills_path(work_experience_id: bob_we.id),
      params: { work_experience_skill: { skill_ids: [ bob_skill.id ] } }.to_json,
      headers: {
        "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}",
        "Content-Type" => "application/json"
      }

    expect(response).to have_http_status(:not_found)
  end
end
