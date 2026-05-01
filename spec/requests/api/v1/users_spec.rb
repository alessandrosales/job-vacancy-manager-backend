# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Users", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/users" do
    get "Lists the current user" do
      tags "Users"
      produces "application/json"
      security [bearer_auth: []]

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/users_list"

        let!(:lister) do
          User.create!(
            name: "Lister",
            email: "lister@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(lister)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to be_an(Array)
          expect(data.size).to eq(1)
          expect(data.first["email"]).to eq("lister@example.com")
          expect(data.first["id"]).to eq(lister.id)
        end
      end

      response 401, "missing or invalid JWT" do
        let(:Authorization) { "Bearer invalid.token.here" }

        run_test!
      end
    end

    post "Registers user (public)" do
      tags "Users"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/user_create_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/user"

        let(:body) do
          {
            user: {
              name: "Ada Lovelace",
              email: "ada@example.com",
              password: "password12",
              password_confirmation: "password12"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["email"]).to eq("ada@example.com")
          expect(data["id"]).to be_present
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:body) do
          {
            user: {
              name: "",
              email: "invalido",
              password: "curta",
              password_confirmation: "outra"
            }
          }
        end

        run_test!
      end
    end
  end

  path "/api/v1/users/{id}" do
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "User UUID"

    get "Fetches user by id" do
      tags "Users"
      produces "application/json"
      security [bearer_auth: []]

      response 200, "found" do
        schema "$ref" => "#/components/schemas/user"

        let(:existing) do
          User.create!(
            name: "Grace Hopper",
            email: "grace@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:id) { existing.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(existing)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["email"]).to eq("grace@example.com")
        end
      end

      response 404, "not found" do
        let(:existing) do
          User.create!(
            name: "Grace Hopper",
            email: "grace404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(existing)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Updates user" do
      tags "Users"
      consumes "application/json"
      produces "application/json"
      security [bearer_auth: []]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/user_update_request" }

      response 200, "updated" do
        schema "$ref" => "#/components/schemas/user"

        let(:existing) do
          User.create!(
            name: "Alan Turing",
            email: "alan@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:id) { existing.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(existing)}" }
        let(:body) { { user: { name: "Alan M. Turing" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["name"]).to eq("Alan M. Turing")
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:existing) do
          User.create!(
            name: "Keep",
            email: "keep@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:id) { existing.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(existing)}" }
        let(:body) { { user: { email: "invalid-email" } } }

        run_test!
      end

      response 404, "not found" do
        let(:existing) do
          User.create!(
            name: "Keep404",
            email: "keep404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(existing)}" }
        let(:id) { SecureRandom.uuid }
        let(:body) { { user: { name: "X" } } }

        run_test!
      end
    end

    delete "Deletes user" do
      tags "Users"
      security [bearer_auth: []]

      response 204, "no content" do
        let!(:existing) do
          User.create!(
            name: "To Delete",
            email: "delete-me@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:id) { existing.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(existing)}" }

        run_test! do
          expect(User.find_by(id: existing.id)).to be_nil
        end
      end

      response 404, "not found" do
        let(:existing) do
          User.create!(
            name: "Del404",
            email: "del404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(existing)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end
  end
end

RSpec.describe "API V1 — Users authorization (request)", type: :request do
  it "returns 401 for GET /api/v1/users without Authorization" do
    get api_v1_users_path
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 403 when fetching another user's record" do
    alice = User.create!(
      name: "Alice",
      email: "alice@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    bob = User.create!(
      name: "Bob",
      email: "bob@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    get api_v1_user_path(bob), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}" }
    expect(response).to have_http_status(:forbidden)
  end
end
