# frozen_string_literal: true

# Join table per docs/db.mermaid — composite PK (work_experience_id, skill_id); user_id denormalized for tenancy checks / future RLS.
class CreateWorkExperienceSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :work_experience_skills, id: false, primary_key: %i[work_experience_id skill_id] do |t|
      t.string :user_id, limit: 36, null: false
      t.string :work_experience_id, limit: 36, null: false
      t.string :skill_id, limit: 36, null: false
      t.timestamps
    end

    add_index :work_experience_skills, :user_id
    add_foreign_key :work_experience_skills, :users, column: :user_id, primary_key: :id
    add_foreign_key :work_experience_skills, :work_experiences, column: :work_experience_id, primary_key: :id
    add_foreign_key :work_experience_skills, :skills, column: :skill_id, primary_key: :id
  end
end
