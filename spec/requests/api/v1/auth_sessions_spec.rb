# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Auth / login", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/auth/login" do
    post "Issues JWT" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/auth_login_request" }

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/auth_login_response"

        let!(:registered) do
          User.create!(
            name: "Auth User",
            email: "auth-user@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end

        let(:body) do
          { auth: { email: "auth-user@example.com", password: "password12" } }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["token"]).to be_present
          expect(data["user"]["email"]).to eq("auth-user@example.com")
        end
      end

      response 401, "invalid credentials" do
        let(:body) do
          { auth: { email: "auth-user@example.com", password: "wrong-password" } }
        end

        run_test!
      end
    end
  end
end
