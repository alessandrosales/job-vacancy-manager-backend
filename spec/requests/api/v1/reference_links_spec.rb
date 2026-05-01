# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Reference links", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/reference_links" do
    get "Lists reference links for the current user" do
      tags "ReferenceLinks"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/reference_links_list"

        let!(:owner) do
          User.create!(
            name: "RL Owner",
            email: "reflinks-owner@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        before do
          owner.reference_links.create!(title: "Docs", url: "https://example.com/docs")
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.size).to eq(1)
          expect(data.first["title"]).to eq("Docs")
          expect(data.first["user_id"]).to eq(owner.id)
        end
      end
    end

    post "Creates reference link (scoped to current user)" do
      tags "ReferenceLinks"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/reference_link_create_request" }

      response 201, "created" do
        schema "$ref" => "#/components/schemas/reference_link"

        let!(:owner) do
          User.create!(
            name: "RL2",
            email: "reflinks-create@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { reference_link: { title: "Board", url: "https://example.com/board" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["title"]).to eq("Board")
          expect(data["user_id"]).to eq(owner.id)
        end
      end

      response 422, "validation errors" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let!(:owner) do
          User.create!(
            name: "RL3",
            email: "reflinks-bad@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { reference_link: { title: "", url: "" } } }

        run_test!
      end
    end
  end

  path "/api/v1/reference_links/{id}" do
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "Reference link UUID"

    get "Fetches reference link" do
      tags "ReferenceLinks"
      produces "application/json"
      security [ bearer_auth: [] ]

      response 200, "found" do
        schema "$ref" => "#/components/schemas/reference_link"

        let!(:owner) do
          User.create!(
            name: "RL4",
            email: "reflinks-show@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:reference_link) { owner.reference_links.create!(title: "T", url: "https://a.com") }
        let(:id) { reference_link.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test!
      end

      response 404, "not found" do
        let!(:owner) do
          User.create!(
            name: "RL5",
            email: "reflinks-404@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Updates reference link" do
      tags "ReferenceLinks"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/reference_link_update_request" }

      response 200, "updated" do
        schema "$ref" => "#/components/schemas/reference_link"

        let!(:owner) do
          User.create!(
            name: "RL6",
            email: "reflinks-patch@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:reference_link) { owner.reference_links.create!(title: "Old", url: "https://old.com") }
        let(:id) { reference_link.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }
        let(:body) { { reference_link: { title: "New", url: "https://new.com" } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["title"]).to eq("New")
        end
      end
    end

    delete "Deletes reference link" do
      tags "ReferenceLinks"
      security [ bearer_auth: [] ]

      response 204, "no content" do
        let!(:owner) do
          User.create!(
            name: "RL7",
            email: "reflinks-del@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let!(:reference_link) { owner.reference_links.create!(title: "X", url: "https://x.com") }
        let(:id) { reference_link.id }
        let(:Authorization) { "Bearer #{User::JwtIssuer.encode(owner)}" }

        run_test! do
          expect(ReferenceLink.find_by(id: reference_link.id)).to be_nil
        end
      end
    end
  end
end

RSpec.describe "API V1 — Reference links isolation", type: :request do
  it "does not return another user's reference link by id" do
    alice = User.create!(name: "A", email: "alice-ref@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "bob-ref@example.com", password: "password12", password_confirmation: "password12")
    link = bob.reference_links.create!(title: "Bob", url: "https://bob.com")

    get api_v1_reference_link_path(link), headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(alice)}" }
    expect(response).to have_http_status(:not_found)
  end
end
