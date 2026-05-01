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

ActiveRecord::Schema[8.1].define(version: 2026_05_01_220840) do
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
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["token"], name: "index_users_on_token", unique: true, where: "token IS NOT NULL"
  end

  add_foreign_key "roles", "users"
  add_foreign_key "skills", "users"
end
