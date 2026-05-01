# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 — Users", openapi_spec: "v1/swagger.yaml" do
  path "/api/v1/users" do
    get "Lista usuários" do
      tags "Users"
      produces "application/json"

      response 200, "OK" do
        schema "$ref" => "#/components/schemas/users_list"

        before do
          User.create!(
            name: "Lister",
            email: "lister@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to be_an(Array)
          expect(data.first["email"]).to eq("lister@example.com")
        end
      end
    end

    post "Cadastra usuário" do
      tags "Users"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/user_create_request" }

      response 201, "criado" do
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

      response 422, "erros de validação" do
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
    parameter name: :id, in: :path, type: :string, format: :uuid, description: "UUID do usuário"

    get "Busca usuário por id" do
      tags "Users"
      produces "application/json"

      response 200, "encontrado" do
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["email"]).to eq("grace@example.com")
        end
      end

      response 404, "não encontrado" do
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch "Atualiza usuário" do
      tags "Users"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/user_update_request" }

      response 200, "atualizado" do
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
        let(:body) { { user: { name: "Alan M. Turing" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["name"]).to eq("Alan M. Turing")
        end
      end

      response 422, "erros de validação" do
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
        let(:body) { { user: { email: "invalid-email" } } }

        run_test!
      end

      response 404, "não encontrado" do
        let(:id) { SecureRandom.uuid }
        let(:body) { { user: { name: "X" } } }

        run_test!
      end
    end

    delete "Remove usuário" do
      tags "Users"

      response 204, "sem conteúdo" do
        let!(:existing) do
          User.create!(
            name: "To Delete",
            email: "delete-me@example.com",
            password: "password12",
            password_confirmation: "password12"
          )
        end
        let(:id) { existing.id }

        run_test! do
          expect(User.find_by(id: existing.id)).to be_nil
        end
      end

      response 404, "não encontrado" do
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end
  end
end
