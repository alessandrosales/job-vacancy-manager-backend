# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Auth / me", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/auth/me" do
    get "Returns the authenticated user" do
      tags "Auth"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/user"

        let!(:me_user) do
          User.create!(
            name: "Me User",
            email: "me-user@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(me_user)}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["id"]).to eq(me_user.id)
          expect(data["email"]).to eq("me-user@example.com")
          expect(data["name"]).to eq("Me User")
        end
      end

      response 401, "missing or invalid JWT" do
        let(:Authorization) { "Bearer invalid.token.here" }

        run_test!
      end
    end
  end
end
