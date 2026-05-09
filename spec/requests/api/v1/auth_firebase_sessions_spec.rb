# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Auth / firebase", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/auth/firebase" do
    post "Issues JWT from Firebase ID token" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/auth_firebase_request" }

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/auth_login_response"

        let(:body) do
          { auth: { id_token: "firebase.token.value" } }
        end

        before do
          allow(User::FirebaseTokenVerifier)
            .to receive(:verify_id_token)
            .with("firebase.token.value")
            .and_return({
              "sub" => "firebase-uid-123",
              "email" => "firebase-user@example.com",
              "email_verified" => true,
              "name" => "Firebase User",
              "picture" => "https://example.com/avatar.png",
              "firebase" => { "sign_in_provider" => "google.com" }
            })
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["token"]).to be_present
          expect(data["user"]["email"]).to eq("firebase-user@example.com")
          expect(data["user"]["avatar_url"]).to be_nil

          user = User.find_by(email: "firebase-user@example.com")
          expect(user).to be_present
          expect(user.firebase_uid).to eq("firebase-uid-123")
          expect(user.avatar_url).to be_nil
        end
      end

      response 401, "invalid firebase token" do
        let(:body) do
          { auth: { id_token: "invalid.token" } }
        end

        before do
          allow(User::FirebaseTokenVerifier)
            .to receive(:verify_id_token)
            .with("invalid.token")
            .and_raise(User::FirebaseTokenVerifier::InvalidTokenError)
        end

        run_test!
      end
    end
  end
end
