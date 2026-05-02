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
          auth_register_request: {
            type: :object,
            properties: {
              auth: {
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
            required: %w[auth]
          },
          auth_recover_password_request: {
            type: :object,
            properties: {
              auth: {
                type: :object,
                properties: {
                  email: { type: :string, format: :email }
                },
                required: %w[email]
              }
            },
            required: %w[auth]
          },
          auth_change_password_request: {
            type: :object,
            properties: {
              auth: {
                type: :object,
                properties: {
                  reset_token: { type: :string, description: "Token from password reset e-mail" },
                  password: { type: :string, minLength: 8, writeOnly: true },
                  password_confirmation: { type: :string, minLength: 8, writeOnly: true }
                },
                required: %w[reset_token password password_confirmation]
              }
            },
            required: %w[auth]
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
          reference_link: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              user_id: { type: :string, format: :uuid },
              title: { type: :string },
              url: { type: :string, format: :uri },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id user_id title url created_at updated_at]
          },
          reference_links_list: {
            type: :array,
            items: { "$ref" => "#/components/schemas/reference_link" }
          },
          reference_link_create_request: {
            type: :object,
            properties: {
              reference_link: {
                type: :object,
                properties: {
                  title: { type: :string },
                  url: { type: :string, format: :uri }
                },
                required: %w[title url]
              }
            },
            required: %w[reference_link]
          },
          reference_link_update_request: {
            type: :object,
            properties: {
              reference_link: {
                type: :object,
                properties: {
                  title: { type: :string },
                  url: { type: :string, format: :uri }
                }
              }
            },
            required: %w[reference_link]
          },
          work_experience: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              user_id: { type: :string, format: :uuid },
              title: { type: :string },
              company_name: { type: :string },
              is_remote: { type: :boolean },
              date_from: { type: :string, format: :date, nullable: true },
              date_to: { type: :string, format: :date, nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id user_id title company_name is_remote created_at updated_at]
          },
          work_experiences_list: {
            type: :array,
            items: { "$ref" => "#/components/schemas/work_experience" }
          },
          work_experience_create_request: {
            type: :object,
            properties: {
              work_experience: {
                type: :object,
                properties: {
                  title: { type: :string },
                  company_name: { type: :string },
                  is_remote: { type: :boolean },
                  date_from: { type: :string, format: :date, nullable: true },
                  date_to: { type: :string, format: :date, nullable: true }
                },
                required: %w[title company_name is_remote]
              }
            },
            required: %w[work_experience]
          },
          work_experience_update_request: {
            type: :object,
            properties: {
              work_experience: {
                type: :object,
                properties: {
                  title: { type: :string },
                  company_name: { type: :string },
                  is_remote: { type: :boolean },
                  date_from: { type: :string, format: :date, nullable: true },
                  date_to: { type: :string, format: :date, nullable: true }
                }
              }
            },
            required: %w[work_experience]
          },
          work_experience_skill_sync_request: {
            type: :object,
            properties: {
              work_experience_skill: {
                type: :object,
                properties: {
                  skill_ids: {
                    type: :array,
                    items: { type: :string, format: :uuid },
                    description: "Full replacement set; empty clears all links."
                  }
                }
              }
            },
            required: %w[work_experience_skill]
          },
          skills_linked_to_work_experience: {
            type: :array,
            items: { "$ref" => "#/components/schemas/skill" }
          },
          certification: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              user_id: { type: :string, format: :uuid },
              name: { type: :string },
              date_from: { type: :string, format: :date, nullable: true },
              date_to: { type: :string, format: :date, nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id user_id name created_at updated_at]
          },
          certifications_list: {
            type: :array,
            items: { "$ref" => "#/components/schemas/certification" }
          },
          certification_create_request: {
            type: :object,
            properties: {
              certification: {
                type: :object,
                properties: {
                  name: { type: :string },
                  date_from: { type: :string, format: :date, nullable: true },
                  date_to: { type: :string, format: :date, nullable: true }
                },
                required: %w[name]
              }
            },
            required: %w[certification]
          },
          certification_update_request: {
            type: :object,
            properties: {
              certification: {
                type: :object,
                properties: {
                  name: { type: :string },
                  date_from: { type: :string, format: :date, nullable: true },
                  date_to: { type: :string, format: :date, nullable: true }
                }
              }
            },
            required: %w[certification]
          },
          education: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              user_id: { type: :string, format: :uuid },
              institution_name: { type: :string },
              degree: { type: :string, nullable: true },
              field_of_study: { type: :string, nullable: true },
              date_from: { type: :string, format: :date, nullable: true },
              date_to: { type: :string, format: :date, nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id user_id institution_name created_at updated_at]
          },
          educations_list: {
            type: :array,
            items: { "$ref" => "#/components/schemas/education" }
          },
          education_create_request: {
            type: :object,
            properties: {
              education: {
                type: :object,
                properties: {
                  institution_name: { type: :string },
                  degree: { type: :string, nullable: true },
                  field_of_study: { type: :string, nullable: true },
                  date_from: { type: :string, format: :date, nullable: true },
                  date_to: { type: :string, format: :date, nullable: true }
                },
                required: %w[institution_name]
              }
            },
            required: %w[education]
          },
          education_update_request: {
            type: :object,
            properties: {
              education: {
                type: :object,
                properties: {
                  institution_name: { type: :string },
                  degree: { type: :string, nullable: true },
                  field_of_study: { type: :string, nullable: true },
                  date_from: { type: :string, format: :date, nullable: true },
                  date_to: { type: :string, format: :date, nullable: true }
                }
              }
            },
            required: %w[education]
          },
          opportunity_status: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              user_id: { type: :string, format: :uuid },
              label: { type: :string },
              description: { type: :string, nullable: true },
              variant: { type: :string, enum: %w[secondary outline default destructive] },
              position: { type: :integer, nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id user_id label variant created_at updated_at]
          },
          opportunity_statuses_list: {
            type: :array,
            items: { "$ref" => "#/components/schemas/opportunity_status" }
          },
          opportunity_status_create_request: {
            type: :object,
            properties: {
              opportunity_status: {
                type: :object,
                properties: {
                  label: { type: :string },
                  description: { type: :string, nullable: true },
                  variant: { type: :string, enum: %w[secondary outline default destructive] },
                  position: { type: :integer, nullable: true }
                },
                required: %w[label variant]
              }
            },
            required: %w[opportunity_status]
          },
          opportunity_status_update_request: {
            type: :object,
            properties: {
              opportunity_status: {
                type: :object,
                properties: {
                  label: { type: :string },
                  description: { type: :string, nullable: true },
                  variant: { type: :string, enum: %w[secondary outline default destructive] },
                  position: { type: :integer, nullable: true }
                }
              }
            },
            required: %w[opportunity_status]
          },
          opportunity: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              user_id: { type: :string, format: :uuid },
              company_id: { type: :string, format: :uuid },
              role_id: { type: :string, format: :uuid },
              description: { type: :string, nullable: true },
              url: { type: :string, nullable: true },
              status_id: { type: :string, format: :uuid },
              interest_level: { type: :integer, minimum: 0, maximum: 5 },
              hourly_rate: { type: :number, nullable: true },
              annual_salary: { type: :number, nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[
              id user_id company_id role_id status_id interest_level created_at updated_at
            ]
          },
          opportunities_list: {
            type: :array,
            items: { "$ref" => "#/components/schemas/opportunity" }
          },
          opportunity_create_request: {
            type: :object,
            properties: {
              opportunity: {
                type: :object,
                properties: {
                  company_id: { type: :string, format: :uuid },
                  role_id: { type: :string, format: :uuid },
                  status_id: { type: :string, format: :uuid },
                  description: { type: :string, nullable: true },
                  url: { type: :string, nullable: true },
                  interest_level: { type: :integer, minimum: 0, maximum: 5 },
                  hourly_rate: { type: :number, nullable: true },
                  annual_salary: { type: :number, nullable: true }
                },
                required: %w[company_id role_id status_id]
              }
            },
            required: %w[opportunity]
          },
          opportunity_update_request: {
            type: :object,
            properties: {
              opportunity: {
                type: :object,
                properties: {
                  company_id: { type: :string, format: :uuid },
                  role_id: { type: :string, format: :uuid },
                  status_id: { type: :string, format: :uuid },
                  description: { type: :string, nullable: true },
                  url: { type: :string, nullable: true },
                  interest_level: { type: :integer, minimum: 0, maximum: 5 },
                  hourly_rate: { type: :number, nullable: true },
                  annual_salary: { type: :number, nullable: true }
                }
              }
            },
            required: %w[opportunity]
          },
          resume: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              user_id: { type: :string, format: :uuid },
              role_id: { type: :string, format: :uuid },
              title: { type: :string },
              description: { type: :string, nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id user_id role_id title created_at updated_at]
          },
          resumes_list: {
            type: :array,
            items: { "$ref" => "#/components/schemas/resume" }
          },
          resume_create_request: {
            type: :object,
            properties: {
              resume: {
                type: :object,
                properties: {
                  title: { type: :string },
                  description: { type: :string, nullable: true },
                  role_id: { type: :string, format: :uuid }
                },
                required: %w[title role_id]
              }
            },
            required: %w[resume]
          },
          resume_update_request: {
            type: :object,
            properties: {
              resume: {
                type: :object,
                properties: {
                  title: { type: :string },
                  description: { type: :string, nullable: true },
                  role_id: { type: :string, format: :uuid }
                }
              }
            },
            required: %w[resume]
          },
          resume_work_experience_sync_request: {
            type: :object,
            properties: {
              resume_work_experience: {
                type: :object,
                properties: {
                  work_experience_ids: {
                    type: :array,
                    items: { type: :string, format: :uuid },
                    description: "Full replacement set; empty clears all links."
                  }
                }
              }
            },
            required: %w[resume_work_experience]
          },
          work_experiences_linked_to_resume: {
            type: :array,
            items: { "$ref" => "#/components/schemas/work_experience" }
          },
          resume_certification_sync_request: {
            type: :object,
            properties: {
              resume_certification: {
                type: :object,
                properties: {
                  certification_ids: {
                    type: :array,
                    items: { type: :string, format: :uuid },
                    description: "Full replacement set; empty clears all links."
                  }
                }
              }
            },
            required: %w[resume_certification]
          },
          certifications_linked_to_resume: {
            type: :array,
            items: { "$ref" => "#/components/schemas/certification" }
          },
          resume_education_sync_request: {
            type: :object,
            properties: {
              resume_education: {
                type: :object,
                properties: {
                  education_ids: {
                    type: :array,
                    items: { type: :string, format: :uuid },
                    description: "Full replacement set; empty clears all links."
                  }
                }
              }
            },
            required: %w[resume_education]
          },
          educations_linked_to_resume: {
            type: :array,
            items: { "$ref" => "#/components/schemas/education" }
          },
          resume_skill_sync_request: {
            type: :object,
            properties: {
              resume_skill: {
                type: :object,
                properties: {
                  skill_ids: {
                    type: :array,
                    items: { type: :string, format: :uuid },
                    description: "Full replacement set; empty clears all links."
                  }
                }
              }
            },
            required: %w[resume_skill]
          },
          skills_linked_to_resume: {
            type: :array,
            items: { "$ref" => "#/components/schemas/skill" }
          },
          pagination_meta: {
            type: :object,
            properties: {
              current_page: { type: :integer, minimum: 1 },
              per_page: { type: :integer, minimum: 1 },
              total_pages: { type: :integer, minimum: 0 },
              total_count: { type: :integer, minimum: 0 }
            },
            required: %w[current_page per_page total_pages total_count]
          },
          paginated_users: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/user" } },
              meta: { "$ref" => "#/components/schemas/pagination_meta" }
            },
            required: %w[data meta]
          },
          paginated_roles: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/role" } },
              meta: { "$ref" => "#/components/schemas/pagination_meta" }
            },
            required: %w[data meta]
          },
          paginated_skills: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/skill" } },
              meta: { "$ref" => "#/components/schemas/pagination_meta" }
            },
            required: %w[data meta]
          },
          paginated_reference_links: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/reference_link" } },
              meta: { "$ref" => "#/components/schemas/pagination_meta" }
            },
            required: %w[data meta]
          },
          paginated_work_experiences: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/work_experience" } },
              meta: { "$ref" => "#/components/schemas/pagination_meta" }
            },
            required: %w[data meta]
          },
          paginated_certifications: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/certification" } },
              meta: { "$ref" => "#/components/schemas/pagination_meta" }
            },
            required: %w[data meta]
          },
          paginated_educations: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/education" } },
              meta: { "$ref" => "#/components/schemas/pagination_meta" }
            },
            required: %w[data meta]
          },
          paginated_opportunity_statuses: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/opportunity_status" } },
              meta: { "$ref" => "#/components/schemas/pagination_meta" }
            },
            required: %w[data meta]
          },
          paginated_opportunities: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/opportunity" } },
              meta: { "$ref" => "#/components/schemas/pagination_meta" }
            },
            required: %w[data meta]
          },
          paginated_resumes: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/resume" } },
              meta: { "$ref" => "#/components/schemas/pagination_meta" }
            },
            required: %w[data meta]
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
