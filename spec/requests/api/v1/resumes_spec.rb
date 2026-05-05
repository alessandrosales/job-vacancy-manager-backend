# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Resumes", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/resumes" do
    get "Lists resumes for the current user (paginated by default)" do
      tags "Resumes"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1 },
        description: "Page number (default 1)."
      parameter name: :per_page, in: :query, required: false, schema: { type: :integer, minimum: 1, maximum: 100 },
        description: "Items per page (default 25, max 100)."
      parameter name: :paginated, in: :query, required: false, schema: { type: :string },
        description: "Send `false`/`0`/`no` to receive the legacy bare array response."

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/paginated_resumes"

        let!(:owner) do
          User.create!(
            name: "Rv Owner",
            email: "resume-owner@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "Backend", interest_level: 4) }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:page) { nil }
        let(:per_page) { nil }
        let(:paginated) { nil }

        before do
          owner.resumes.create!(title: "CV 2026", role: role, description: "Hello")
        end

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload).to include("data", "meta")
          expect(payload["data"].size).to eq(1)
          expect(payload["data"].first["title"]).to eq("CV 2026")
          expect(payload["data"].first["role_id"]).to eq(role.id)
        end
      end
    end

    post "Creates resume (scoped to current user)" do
      tags "Resumes"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/resume_create_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/resume"

        let!(:owner) do
          User.create!(
            name: "Rv C",
            email: "resume-create@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "SRE", interest_level: 3) }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { resume: { title: "Main", role_id: role.id, description: "Ops" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["title"]).to eq("Main")
          expect(data["user_id"]).to eq(owner.id)
          expect(data["preferred_language"]).to eq("en")
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "Rv Bad",
            email: "resume-bad@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "X", interest_level: 1) }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { resume: { title: "", role_id: role.id } } }

        run_test!
      end
    end
  end

  path "/api/v1/resumes/{id}" do
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "Resume UUID"

    get "Fetches resume" do
      tags "Resumes"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "found" do
        schema "$ref" => "#/components/schemas/resume"

        let!(:owner) do
          User.create!(
            name: "Rv Show",
            email: "resume-show@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "Dev", interest_level: 2) }
        let(:resume) { owner.resumes.create!(title: "Show me", role: role) }
        let(:id) { resume.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test!
      end

      response 404, "not found" do
        let!(:owner) do
          User.create!(
            name: "Rv 404",
            email: "resume-404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Updates resume" do
      tags "Resumes"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/resume_update_request" }

      response 200, "updated" do
        schema "$ref" => "#/components/schemas/resume"

        let!(:owner) do
          User.create!(
            name: "Rv Patch",
            email: "resume-patch@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "FE", interest_level: 2) }
        let(:resume) { owner.resumes.create!(title: "Old", role: role) }
        let(:id) { resume.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) do
          { resume: {
            title: "New title",
            description: "Updated body",
            preferred_language: "pt_br",
          }, }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["title"]).to eq("New title")
          expect(data["preferred_language"]).to eq("pt_br")
        end
      end
    end

    delete "Deletes resume" do
      tags "Resumes"
      security [ bearer_auth: [] ]

      response 204, "no content" do
        let!(:owner) do
          User.create!(
            name: "Rv Del",
            email: "resume-del@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "Del role", interest_level: 0) }
        let!(:resume) { owner.resumes.create!(title: "Trash", role: role) }
        let(:id) { resume.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test! do
          expect(Resume.find_by(id: resume.id)).to be_nil
        end
      end
    end
  end
end

RSpec.describe "API V1 — Resumes pagination", type: :request do
  it_behaves_like "paginated index", path: "/api/v1/resumes" do
    let!(:owner) do
      User.create!(
        name: "Pag", email: "resume-pag@example.com",
        password: "password12", password_confirmation: "password12"
      )
    end
    let(:authorization_header) { "Bearer #{User::JwtIssuer.encode(owner)}" }
    let(:expected_total) { 3 }

    before do
      role = owner.roles.create!(name: "Pag Role", interest_level: 1)
      3.times { |i| owner.resumes.create!(title: "R#{i}", role: role) }
    end
  end
end

RSpec.describe "API V1 — Resumes isolation", type: :request do
  it "does not return another user's resume by id" do
    alice = User.create!(name: "A", email: "alice-rv@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "bob-rv@example.com", password: "password12", password_confirmation: "password12")
    role = bob.roles.create!(name: "Bob role", interest_level: 1)
    bob_resume = bob.resumes.create!(title: "Secret", role: role)

    get api_v1_resume_path(bob_resume), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}" }
    expect(response).to have_http_status(:not_found)
  end
end

RSpec.describe "API V1 — Resumes association ids", type: :request do
  it "returns work_experience_ids in sync order on GET show" do
    owner = User.create!(
      name: "Rv Links",
      email: "resume-links@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    role = owner.roles.create!(name: "Dev", interest_level: 3)
    resume = owner.resumes.create!(title: "Linked", role: role)
    we_second = owner.work_experiences.create!(title: "Second", company_name: "Co", is_remote: false)
    we_first = owner.work_experiences.create!(title: "First", company_name: "Co", is_remote: false)
    resume.sync_work_experience_links!(owner, [ we_second.id, we_first.id ])

    get api_v1_resume_path(resume), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(owner)}" }

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["work_experience_ids"]).to eq([ we_second.id, we_first.id ])
    expect(body["certification_ids"]).to eq([])
    expect(body["education_ids"]).to eq([])
    expect(body["skill_ids"]).to eq([])
  end
end
