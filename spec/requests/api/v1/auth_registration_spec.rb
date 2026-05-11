# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Auth / register", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/auth/register" do
    post "Creates account and returns JWT" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/auth_register_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/auth_login_response"

        let(:body) do
          {
            auth: {
              name: "Nova Conta",
              email: "register-auth@example.com",
              password: "password12",
              password_confirmation: "password12"
            }
          }
        end

        before { ActionMailer::Base.deliveries.clear }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["token"]).to be_present
          expect(data["user"]["email"]).to eq("register-auth@example.com")
          expect(ActionMailer::Base.deliveries.size).to eq(1)
          mail = ActionMailer::Base.deliveries.last
          expect(mail.to).to eq([ "register-auth@example.com" ])
          expect(mail.subject).to eq(I18n.t("registration_mailer.welcome.subject", locale: :en))
          expect(mail.body.raw_source).to include("Thanks for signing up")
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:existing) do
          User.create!(
            name: "Existing",
            email: "dup-register@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end

        let(:body) do
          {
            auth: {
              name: "X",
              email: "dup-register@example.com",
              password: "password12",
              password_confirmation: "password12"
            }
          }
        end

        run_test!
      end
    end

    # Sem swagger spec: o cenário do `preferred_language` foi documentado em `auth_register_request`.
    describe "preferred_language vindo da landing/login" do
      it "persiste o idioma escolhido na criação" do
        post "/api/v1/auth/register", params: {
          auth: {
            name: "Conta PT",
            email: "register-pt@example.com",
            password: "password12",
            password_confirmation: "password12",
            preferred_language: "pt_br"
          }
        }, as: :json
        expect(response).to have_http_status(:created)
        user = User.find_by!(email: "register-pt@example.com")
        expect(user.preferred_language).to eq("pt_br")
      end

      it "cai no default 'en' quando o idioma é inválido" do
        post "/api/v1/auth/register", params: {
          auth: {
            name: "Conta default",
            email: "register-default@example.com",
            password: "password12",
            password_confirmation: "password12",
            preferred_language: "fr"
          }
        }, as: :json
        expect(response).to have_http_status(:created)
        user = User.find_by!(email: "register-default@example.com")
        expect(user.preferred_language).to eq("en")
      end
    end
  end
end
