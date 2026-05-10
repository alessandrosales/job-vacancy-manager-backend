# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Users", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/users" do
    get "Lists the current user (paginated by default)" do
      tags "Users"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1 },
        description: "Page number (default 1)."
      parameter name: :per_page, in: :query, required: false, schema: { type: :integer, minimum: 1, maximum: 100 },
        description: "Items per page (default 25, max 100)."
      parameter name: :paginated, in: :query, required: false, schema: { type: :string },
        description: "Send `false`/`0`/`no` to receive the legacy bare array response."

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/paginated_users"

        let!(:lister) do
          User.create!(
            name: "Lister",
            email: "lister@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(lister)}" }
        let(:page) { nil }
        let(:per_page) { nil }
        let(:paginated) { nil }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload).to include("data", "meta")
          expect(payload["data"]).to be_an(Array)
          expect(payload["data"].size).to eq(1)
          expect(payload["data"].first["email"]).to eq("lister@example.com")
          expect(payload["data"].first["id"]).to eq(lister.id)
          expect(payload["meta"]).to include(
            "current_page" => 1,
            "per_page" => 25,
            "total_pages" => 1,
            "total_count" => 1
          )
        end
      end

      response 401, "missing or invalid JWT" do
        let(:Authorization) { "Bearer invalid.token.here" }
        let(:page) { nil }
        let(:per_page) { nil }
        let(:paginated) { nil }

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
      security [ bearer_auth: [] ]

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
      security [ bearer_auth: [] ]
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

        before { ActionMailer::Base.deliveries.clear }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["name"]).to eq("Alan M. Turing")
          expect(ActionMailer::Base.deliveries).to be_empty
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
      security [ bearer_auth: [] ]

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

RSpec.describe "API V1 — Users pagination", type: :request do
  it_behaves_like "paginated index", path: "/api/v1/users" do
    let!(:owner) do
      User.create!(
        name: "Pag Owner",
        email: "users-pag@example.com",
        password: "password12",
        password_confirmation: "password12"
      )
    end
    let(:authorization_header) { "Bearer #{User::JwtIssuer.encode(owner)}" }
    let(:expected_total) { 1 }
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

  it "does not send password-changed e-mail when patch omits password" do
    ActionMailer::Base.deliveries.clear
    user = User.create!(
      name: "No Mail",
      email: "no-mail-pass@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    patch api_v1_user_path(user),
      params: { user: { name: "No Mail Jr" } }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{User::JwtIssuer.encode(user)}"
      }
    expect(response).to have_http_status(:ok)
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "sends password-changed e-mail when password is updated via PATCH" do
    ActionMailer::Base.deliveries.clear
    user = User.create!(
      name: "Pwd Mail",
      email: "pwd-mail@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    patch api_v1_user_path(user),
      params: {
        user: {
          password: "newpassword12",
          password_confirmation: "newpassword12"
        }
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{User::JwtIssuer.encode(user)}"
      }
    expect(response).to have_http_status(:ok)
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ "pwd-mail@example.com" ])
    expect(mail.subject).to eq(I18n.t("password_mailer.password_changed.subject", locale: :en))
  end

  it "persists optional profile fields on PATCH" do
    user = User.create!(
      name: "Profile User",
      email: "profile-fields@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    patch api_v1_user_path(user),
      params: {
        user: {
          phone: "+55 11 99999-9999",
          avatar_url: "https://example.com/a.png",
          bio: "Backend dev",
          age: 32,
          full_address: "Rua 1, 10 — São Paulo",
          relationship_status: "single",
          gender: "female"
        }
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{User::JwtIssuer.encode(user)}"
      }
    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body)
    expect(data["phone"]).to eq("+55 11 99999-9999")
    expect(data["avatar_url"]).to eq("https://example.com/a.png")
    expect(data["bio"]).to eq("Backend dev")
    expect(data["age"]).to eq(32)
    expect(data["full_address"]).to eq("Rua 1, 10 — São Paulo")
    expect(data["relationship_status"]).to eq("single")
    expect(data["gender"]).to eq("female")
  end

  it "stores and clears ai_token without returning the secret" do
    user = User.create!(
      name: "Ai Key User",
      email: "ai-key@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    patch api_v1_user_path(user),
      params: { user: { ai_token: "sk-user-test-key" } }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{User::JwtIssuer.encode(user)}"
      }
    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body)
    expect(data["ai_token_configured"]).to eq(true)
    expect(data).not_to have_key("ai_token")
    expect(user.reload.ai_token).to eq("sk-user-test-key")

    patch api_v1_user_path(user),
      params: { user: { ai_token: "" } }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{User::JwtIssuer.encode(user)}"
      }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["ai_token_configured"]).to eq(false)
    expect(user.reload.ai_token).to be_nil
  end
end
