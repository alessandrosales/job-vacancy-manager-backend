# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_05_233838) do
  create_table "certifications", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_from"
    t.date "date_to"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_certifications_on_user_id"
  end

  create_table "companies", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "interest_level", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_companies_on_user_id"
  end

  create_table "educations", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_from"
    t.date "date_to"
    t.string "degree"
    t.string "field_of_study"
    t.string "institution_name", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_educations_on_user_id"
  end

  create_table "languages", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "level", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_languages_on_user_id"
  end

  create_table "opportunities", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.decimal "annual_salary", precision: 14, scale: 2
    t.string "company_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.decimal "hourly_rate", precision: 12, scale: 2
    t.integer "interest_level", default: 0, null: false
    t.string "role_id", limit: 36, null: false
    t.string "status_id", limit: 36, null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "user_id", limit: 36, null: false
    t.index ["company_id"], name: "index_opportunities_on_company_id"
    t.index ["role_id"], name: "index_opportunities_on_role_id"
    t.index ["status_id"], name: "index_opportunities_on_status_id"
    t.index ["user_id"], name: "index_opportunities_on_user_id"
  end

  create_table "opportunity_statuses", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "label", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.string "variant", null: false
    t.index ["user_id"], name: "index_opportunity_statuses_on_user_id"
  end

  create_table "reference_links", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_reference_links_on_user_id"
  end

  create_table "resume_certifications", id: false, force: :cascade do |t|
    t.string "certification_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.string "resume_id", limit: 36, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_resume_certifications_on_user_id"
  end

  create_table "resume_educations", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "education_id", limit: 36, null: false
    t.string "resume_id", limit: 36, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_resume_educations_on_user_id"
  end

  create_table "resume_skills", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "resume_id", limit: 36, null: false
    t.string "skill_id", limit: 36, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_resume_skills_on_user_id"
  end

  create_table "resume_work_experiences", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "resume_id", limit: 36, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.string "work_experience_id", limit: 36, null: false
    t.index ["user_id"], name: "index_resume_work_experiences_on_user_id"
  end

  create_table "resumes", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.text "compiled_markdown"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "preferred_language", default: "en", null: false
    t.string "role_id", limit: 36, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["role_id"], name: "index_resumes_on_role_id"
    t.index ["user_id"], name: "index_resumes_on_user_id"
  end

  create_table "roles", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "interest_level", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_roles_on_user_id"
  end

  create_table "skills", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_skills_on_user_id"
  end

  create_table "users", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.integer "age"
    t.string "avatar_url"
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.text "full_address"
    t.string "gender"
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "phone"
    t.string "preferred_language", default: "en", null: false
    t.string "relationship_status"
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["token"], name: "index_users_on_token", unique: true, where: "token IS NOT NULL"
  end

  create_table "work_experience_skills", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "skill_id", limit: 36, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.string "work_experience_id", limit: 36, null: false
    t.index ["user_id"], name: "index_work_experience_skills_on_user_id"
  end

  create_table "work_experiences", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "company_name", null: false
    t.datetime "created_at", null: false
    t.date "date_from"
    t.date "date_to"
    t.boolean "is_remote", default: false, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["user_id"], name: "index_work_experiences_on_user_id"
  end

  add_foreign_key "certifications", "users"
  add_foreign_key "companies", "users"
  add_foreign_key "educations", "users"
  add_foreign_key "languages", "users"
  add_foreign_key "opportunities", "companies"
  add_foreign_key "opportunities", "opportunity_statuses", column: "status_id"
  add_foreign_key "opportunities", "roles"
  add_foreign_key "opportunities", "users"
  add_foreign_key "opportunity_statuses", "users"
  add_foreign_key "reference_links", "users"
  add_foreign_key "resume_certifications", "certifications"
  add_foreign_key "resume_certifications", "resumes"
  add_foreign_key "resume_certifications", "users"
  add_foreign_key "resume_educations", "educations"
  add_foreign_key "resume_educations", "resumes"
  add_foreign_key "resume_educations", "users"
  add_foreign_key "resume_skills", "resumes"
  add_foreign_key "resume_skills", "skills"
  add_foreign_key "resume_skills", "users"
  add_foreign_key "resume_work_experiences", "resumes"
  add_foreign_key "resume_work_experiences", "users"
  add_foreign_key "resume_work_experiences", "work_experiences"
  add_foreign_key "resumes", "roles"
  add_foreign_key "resumes", "users"
  add_foreign_key "roles", "users"
  add_foreign_key "skills", "users"
  add_foreign_key "work_experience_skills", "skills"
  add_foreign_key "work_experience_skills", "users"
  add_foreign_key "work_experience_skills", "work_experiences"
  add_foreign_key "work_experiences", "users"
end
