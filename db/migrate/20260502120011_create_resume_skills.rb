# frozen_string_literal: true

class CreateResumeSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :resume_skills, id: false, primary_key: %i[resume_id skill_id] do |t|
      t.string :user_id, limit: 36, null: false
      t.string :resume_id, limit: 36, null: false
      t.string :skill_id, limit: 36, null: false
      t.timestamps
    end

    add_index :resume_skills, :user_id
    add_foreign_key :resume_skills, :users, column: :user_id, primary_key: :id
    add_foreign_key :resume_skills, :resumes, column: :resume_id, primary_key: :id
    add_foreign_key :resume_skills, :skills, column: :skill_id, primary_key: :id
  end
end
