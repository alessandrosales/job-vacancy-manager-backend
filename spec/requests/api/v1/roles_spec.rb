# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Roles", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/roles" do
    get "Lists roles for the current user (paginated by default)" do
      tags "Roles"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1 },
        description: "Page number (default 1)."
      parameter name: :per_page, in: :query, required: false, schema: { type: :integer, minimum: 1, maximum: 100 },
        description: "Items per page (default 25, max 100)."
      parameter name: :paginated, in: :query, required: false, schema: { type: :string },
        description: "Send `false`/`0`/`no` to receive the legacy bare array response."

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/paginated_roles"

        let!(:owner) do
          User.create!(
            name: "Owner",
            email: "roles-owner@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:page) { nil }
        let(:per_page) { nil }
        let(:paginated) { nil }

        before do
          owner.roles.create!(name: "Backend", description: "Ruby", interest_level: 5)
        end

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload).to include("data", "meta")
          expect(payload["data"].size).to eq(1)
          expect(payload["data"].first["name"]).to eq("Backend")
          expect(payload["data"].first["user_id"]).to eq(owner.id)
          expect(payload["meta"]).to include("current_page" => 1, "per_page" => 25, "total_count" => 1)
        end
      end
    end

    post "Creates role (scoped to current user)" do
      tags "Roles"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/role_create_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/role"

        let!(:owner) do
          User.create!(
            name: "Owner2",
            email: "roles-create@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { role: { name: "Frontend", description: "React", interest_level: 3 } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["name"]).to eq("Frontend")
          expect(data["user_id"]).to eq(owner.id)
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "Owner3",
            email: "roles-bad@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { role: { name: "", interest_level: 99 } } }

        run_test!
      end

      response 422, "duplicate name for user" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "OwnerDup",
            email: "roles-dup@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        before do
          owner.roles.create!(name: "Designer", interest_level: 2)
        end

        let(:body) { { role: { name: "designer", interest_level: 4 } } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["errors"]).to be_a(Hash)
          expect(json["errors"]["name"]).to be_present
        end
      end
    end
  end

  path "/api/v1/roles/{id}" do
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "Role UUID"

    get "Fetches role" do
      tags "Roles"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "found" do
        schema "$ref" => "#/components/schemas/role"

        let!(:owner) do
          User.create!(
            name: "Owner4",
            email: "roles-show@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "PM", interest_level: 2) }
        let(:id) { role.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test!
      end

      response 404, "not found" do
        let!(:owner) do
          User.create!(
            name: "Owner5",
            email: "roles-404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Updates role" do
      tags "Roles"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/role_update_request" }

      response 200, "updated" do
        schema "$ref" => "#/components/schemas/role"

        let!(:owner) do
          User.create!(
            name: "Owner6",
            email: "roles-patch@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:role) { owner.roles.create!(name: "Old", interest_level: 1) }
        let(:id) { role.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { role: { name: "New title", interest_level: 4 } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["name"]).to eq("New title")
        end
      end
    end

    delete "Deletes role" do
      tags "Roles"
      security [ bearer_auth: [] ]

      response 204, "no content" do
        let!(:owner) do
          User.create!(
            name: "Owner7",
            email: "roles-del@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:role) { owner.roles.create!(name: "Gone", interest_level: 0) }
        let(:id) { role.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test! do
          expect(Role.find_by(id: role.id)).to be_nil
        end
      end
    end
  end
end

RSpec.describe "API V1 — Roles pagination", type: :request do
  it_behaves_like "paginated index", path: "/api/v1/roles" do
    let!(:owner) do
      User.create!(
        name: "Pag", email: "roles-pag@example.com",
        password: "password12", password_confirmation: "password12"
      )
    end
    let(:authorization_header) { "Bearer #{User::JwtIssuer.encode(owner)}" }
    let(:expected_total) { 3 }

    before do
      3.times { |i| owner.roles.create!(name: "R#{i}", interest_level: 1) }
    end
  end
end

RSpec.describe "API V1 — Roles isolation", type: :request do
  it "does not return another user's role by id" do
    alice = User.create!(name: "A", email: "alice-iso@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "bob-iso@example.com", password: "password12", password_confirmation: "password12")
    bob_role = bob.roles.create!(name: "Bob only", interest_level: 1)

    get api_v1_role_path(bob_role), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}" }
    expect(response).to have_http_status(:not_found)
  end
end
