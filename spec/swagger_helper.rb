# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Job Vacancy Manager API",
        version: "1.0.0",
        description: "API REST versionada em `/api/v1`. Chaves primárias e estrangeiras em UUID."
      },
      paths: {},
      servers: [
        {
          url: "http://localhost:3000",
          description: "Desenvolvimento"
        }
      ],
      components: {
        schemas: {
          user: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              name: { type: :string },
              email: { type: :string, format: :email },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id name email created_at updated_at]
          },
          users_list: {
            type: :array,
            items: { "$ref" => "#/components/schemas/user" }
          },
          user_create_request: {
            type: :object,
            properties: {
              user: {
                type: :object,
                properties: {
                  name: { type: :string },
                  email: { type: :string, format: :email },
                  password: { type: :string, minLength: 8, writeOnly: true },
                  password_confirmation: { type: :string, minLength: 8, writeOnly: true }
                },
                required: %w[name email password password_confirmation]
              }
            },
            required: %w[user]
          },
          user_update_request: {
            type: :object,
            properties: {
              user: {
                type: :object,
                properties: {
                  name: { type: :string },
                  email: { type: :string, format: :email },
                  password: { type: :string, minLength: 8, writeOnly: true },
                  password_confirmation: { type: :string, minLength: 8, writeOnly: true }
                }
              }
            },
            required: %w[user]
          },
          validation_errors: {
            type: :object,
            properties: {
              errors: {
                type: :object,
                additionalProperties: {
                  type: :array,
                  items: { type: :string }
                }
              }
            }
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
