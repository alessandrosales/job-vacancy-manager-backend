# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Resume ↔ work experiences (sync)", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/resumes/{resume_id}/work_experiences" do
    parameter name: :resume_id, in: :path, type: :string, format: :uuid, description: "Resume UUID"

    patch "Syncs work experiences (full replacement)" do
      tags "ResumeWorkExperiences"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/resume_work_experience_sync_request" }

      response 200, "updated list" do
        schema "$ref" => "#/components/schemas/work_experiences_linked_to_resume"

        let!(:owner) do
          User.create!(
            name: "RWE",
            email: "rwe-sync@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "Eng", interest_level: 3) }
        let!(:resume) { owner.resumes.create!(title: "CV", role: role) }
        let!(:we_a) { owner.work_experiences.create!(title: "A", company_name: "Co", is_remote: true) }
        let!(:we_b) { owner.work_experiences.create!(title: "B", company_name: "Inc", is_remote: false) }
        let(:resume_id) { resume.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { resume_work_experience: { work_experience_ids: [ we_b.id, we_a.id ] } } }

        run_test! do |response|
          expect(JSON.parse(response.body).map { |h| h["id"] }).to eq([ we_b.id, we_a.id ])
        end
      end
    end
  end
end

RSpec.describe "API V1 — Resume ↔ certifications (sync)", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/resumes/{resume_id}/certifications" do
    parameter name: :resume_id, in: :path, type: :string, format: :uuid, description: "Resume UUID"

    patch "Syncs certifications (full replacement)" do
      tags "ResumeCertifications"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/resume_certification_sync_request" }

      response 200, "updated list" do
        schema "$ref" => "#/components/schemas/certifications_linked_to_resume"

        let!(:owner) do
          User.create!(
            name: "RC",
            email: "rc-sync@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "R", interest_level: 2) }
        let!(:resume) { owner.resumes.create!(title: "CV", role: role) }
        let!(:c_a) { owner.certifications.create!(name: "AWS") }
        let!(:c_b) { owner.certifications.create!(name: "GCP") }
        let(:resume_id) { resume.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { resume_certification: { certification_ids: [ c_b.id, c_a.id ] } } }

        run_test! do |response|
          expect(JSON.parse(response.body).map { |h| h["name"] }).to eq(%w[GCP AWS])
        end
      end

      response 422, "foreign certification" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "RC422",
            email: "rc422@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:other) do
          User.create!(
            name: "O",
            email: "rc-other@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:foreign_cert) { other.certifications.create!(name: "X") }
        let(:role) { owner.roles.create!(name: "Z", interest_level: 0) }
        let!(:resume) { owner.resumes.create!(title: "CV", role: role) }
        let(:resume_id) { resume.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { resume_certification: { certification_ids: [ foreign_cert.id ] } } }

        run_test!
      end
    end
  end
end

RSpec.describe "API V1 — Resume ↔ educations (sync)", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/resumes/{resume_id}/educations" do
    parameter name: :resume_id, in: :path, type: :string, format: :uuid, description: "Resume UUID"

    patch "Syncs educations (full replacement)" do
      tags "ResumeEducations"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/resume_education_sync_request" }

      response 200, "updated list" do
        schema "$ref" => "#/components/schemas/educations_linked_to_resume"

        let!(:owner) do
          User.create!(
            name: "RE",
            email: "re-sync@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "Edu", interest_level: 2) }
        let!(:resume) { owner.resumes.create!(title: "CV", role: role) }
        let!(:edu) { owner.educations.create!(institution_name: "Uni") }
        let(:resume_id) { resume.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { resume_education: { education_ids: [ edu.id ] } } }

        run_test! do |response|
          expect(JSON.parse(response.body).first["institution_name"]).to eq("Uni")
        end
      end
    end
  end
end

RSpec.describe "API V1 — Resume ↔ skills (sync)", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/resumes/{resume_id}/skills" do
    parameter name: :resume_id, in: :path, type: :string, format: :uuid, description: "Resume UUID"

    patch "Syncs skills (full replacement)" do
      tags "ResumeSkills"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/resume_skill_sync_request" }

      response 200, "updated list" do
        schema "$ref" => "#/components/schemas/skills_linked_to_resume"

        let!(:owner) do
          User.create!(
            name: "RS",
            email: "rs-sync@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "Sk", interest_level: 4) }
        let!(:resume) { owner.resumes.create!(title: "CV", role: role) }
        let!(:skill) { owner.skills.create!(name: "Rust") }
        let(:resume_id) { resume.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { resume_skill: { skill_ids: [ skill.id ] } } }

        run_test! do |response|
          expect(JSON.parse(response.body).first["name"]).to eq("Rust")
        end
      end
    end
  end
end
