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
        description: "REST API under `/api/v1`. JSON keys use snake_case. Primary keys are UUIDs. Protected routes expect `Authorization: Bearer <jwt>`."
      },
      paths: {},
      servers: [
        {
          url: "http://localhost:3000",
          description: "Development"
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: "JWT"
          }
        },
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
          auth_login_request: {
            type: :object,
            properties: {
              auth: {
                type: :object,
                properties: {
                  email: { type: :string, format: :email },
                  password: { type: :string, writeOnly: true }
                },
                required: %w[email password]
              }
            },
            required: %w[auth]
          },
          auth_login_response: {
            type: :object,
            properties: {
              token: { type: :string, description: "HS256 JWT" },
              user: { "$ref" => "#/components/schemas/user" }
            },
            required: %w[token user]
          },
          role: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              user_id: { type: :string, format: :uuid },
              name: { type: :string },
              description: { type: :string, nullable: true },
              interest_level: { type: :integer, minimum: 0, maximum: 5 },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id user_id name interest_level created_at updated_at]
          },
          roles_list: {
            type: :array,
            items: { "$ref" => "#/components/schemas/role" }
          },
          role_create_request: {
            type: :object,
            properties: {
              role: {
                type: :object,
                properties: {
                  name: { type: :string },
                  description: { type: :string, nullable: true },
                  interest_level: { type: :integer, minimum: 0, maximum: 5 }
                },
                required: %w[name]
              }
            },
            required: %w[role]
          },
          role_update_request: {
            type: :object,
            properties: {
              role: {
                type: :object,
                properties: {
                  name: { type: :string },
                  description: { type: :string, nullable: true },
                  interest_level: { type: :integer, minimum: 0, maximum: 5 }
                }
              }
            },
            required: %w[role]
          },
          skill: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              user_id: { type: :string, format: :uuid },
              name: { type: :string },
              description: { type: :string, nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id user_id name created_at updated_at]
          },
          skills_list: {
            type: :array,
            items: { "$ref" => "#/components/schemas/skill" }
          },
          skill_create_request: {
            type: :object,
            properties: {
              skill: {
                type: :object,
                properties: {
                  name: { type: :string },
                  description: { type: :string, nullable: true }
                },
                required: %w[name]
              }
            },
            required: %w[skill]
          },
          skill_update_request: {
            type: :object,
            properties: {
              skill: {
                type: :object,
                properties: {
                  name: { type: :string },
                  description: { type: :string, nullable: true }
                }
              }
            },
            required: %w[skill]
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
