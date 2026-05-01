# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Certifications", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/certifications" do
    get "Lists certifications for the current user" do
      tags "Certifications"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/certifications_list"

        let!(:owner) do
          User.create!(
            name: "Cert Owner",
            email: "certs-owner@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        before do
          owner.certifications.create!(name: "AWS SA", date_from: Date.new(2020, 1, 1))
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.size).to eq(1)
          expect(data.first["name"]).to eq("AWS SA")
          expect(data.first["user_id"]).to eq(owner.id)
        end
      end
    end

    post "Creates certification (scoped to current user)" do
      tags "Certifications"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/certification_create_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/certification"

        let!(:owner) do
          User.create!(
            name: "Cert C",
            email: "certs-create@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { certification: { name: "CKA", date_from: "2019-06-01", date_to: "2022-06-01" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["name"]).to eq("CKA")
          expect(data["user_id"]).to eq(owner.id)
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "Cert Bad",
            email: "certs-bad@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { certification: { name: "" } } }

        run_test!
      end
    end
  end

  path "/api/v1/certifications/{id}" do
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "Certification UUID"

    get "Fetches certification" do
      tags "Certifications"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "found" do
        schema "$ref" => "#/components/schemas/certification"

        let!(:owner) do
          User.create!(
            name: "Cert Show",
            email: "certs-show@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:certification) { owner.certifications.create!(name: "PMP") }
        let(:id) { certification.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test!
      end

      response 404, "not found" do
        let!(:owner) do
          User.create!(
            name: "Cert 404",
            email: "certs-404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Updates certification" do
      tags "Certifications"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/certification_update_request" }

      response 200, "updated" do
        schema "$ref" => "#/components/schemas/certification"

        let!(:owner) do
          User.create!(
            name: "Cert Patch",
            email: "certs-patch@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:certification) { owner.certifications.create!(name: "Old") }
        let(:id) { certification.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { certification: { name: "New title", date_from: "2021-01-01" } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["name"]).to eq("New title")
        end
      end
    end

    delete "Deletes certification" do
      tags "Certifications"
      security [ bearer_auth: [] ]

      response 204, "no content" do
        let!(:owner) do
          User.create!(
            name: "Cert Del",
            email: "certs-del@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:certification) { owner.certifications.create!(name: "Remove") }
        let(:id) { certification.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test! do
          expect(Certification.find_by(id: certification.id)).to be_nil
        end
      end
    end
  end
end

RSpec.describe "API V1 — Certifications isolation", type: :request do
  it "does not return another user's certification by id" do
    alice = User.create!(name: "A", email: "alice-cert@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "bob-cert@example.com", password: "password12", password_confirmation: "password12")
    bob_cert = bob.certifications.create!(name: "Secret")

    get api_v1_certification_path(bob_cert), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}" }
    expect(response).to have_http_status(:not_found)
  end
end
