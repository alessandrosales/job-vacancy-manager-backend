# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Auth / password reset", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/auth/recover-password" do
    post "Sends reset e-mail if account exists (always 204)" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/auth_recover_password_request" }

      response 204, "no content (same when email unknown — no enumeration)" do
        let!(:user) do
          User.create!(
            name: "Recover User",
            email: "recover-auth@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end

        let(:body) { { auth: { email: "recover-auth@example.com" } } }

        before { ActionMailer::Base.deliveries.clear }

        run_test! do
          expect(ActionMailer::Base.deliveries.size).to eq(1)
          mail = ActionMailer::Base.deliveries.last
          expect(mail.to).to eq([ "recover-auth@example.com" ])
          raw = mail.text_part&.decoded || mail.body.raw_source
          token = raw.scan(/[A-Za-z0-9_=-]{24,}/).max_by(&:length)
          expect(token).to be_present
          expect(User.find_by_token_for(:password_reset, token)).to eq(user)
        end
      end
    end
  end

  describe "POST /api/v1/auth/recover-password (no swagger)" do
    it "returns 204 when JSON body is empty but Content-Type is application/json" do
      ActionMailer::Base.deliveries.clear
      post "/api/v1/auth/recover-password",
        params: "",
        headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:no_content)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "returns 400 JSON when body is not valid JSON" do
      post "/api/v1/auth/recover-password",
        params: "{not-json",
        headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:bad_request)
      data = JSON.parse(response.body)
      expect(data["errors"]["base"].first).to include("Invalid JSON")
    end

    it "returns 204 and sends nothing when email is unknown" do
      ActionMailer::Base.deliveries.clear
      post "/api/v1/auth/recover-password",
        params: { auth: { email: "unknown-email@example.com" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:no_content)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  path "/api/v1/auth/change-password" do
    post "Sets new password using reset token; returns JWT" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/auth_change_password_request" }

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/auth_login_response"

        let!(:user) do
          User.create!(
            name: "Change Pass User",
            email: "change-auth@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end

        let(:reset_token) { user.generate_token_for(:password_reset) }

        let(:body) do
          {
            auth: {
              reset_token: reset_token,
              password: "newpass123",
              password_confirmation: "newpass123"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["token"]).to be_present
          user.reload
          expect(user.authenticate("newpass123")).to eq(user)
        end
      end

      response 422, "invalid token, expired token, or password validation" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:body) do
          {
            auth: {
              reset_token: "invalid-token",
              password: "newpass123",
              password_confirmation: "newpass123"
            }
          }
        end

        run_test!
      end
    end
  end

  describe "POST /api/v1/auth/change-password (no swagger)" do
    it "returns 422 when password is too short" do
      user = User.create!(
        name: "Short Pass User",
        email: "short-pass@example.com",
        password: "password12",
        password_confirmation: "password12"
      )
      token = user.generate_token_for(:password_reset)
      post "/api/v1/auth/change-password",
        params: {
          auth: {
            reset_token: token,
            password: "short",
            password_confirmation: "short"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
      data = JSON.parse(response.body)
      expect(data["errors"]).to be_present
    end
  end
end
