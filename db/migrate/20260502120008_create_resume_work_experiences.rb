# frozen_string_literal: true

class CreateResumeWorkExperiences < ActiveRecord::Migration[8.1]
  def change
    create_table :resume_work_experiences, id: false, primary_key: %i[resume_id work_experience_id] do |t|
      t.string :user_id, limit: 36, null: false
      t.string :resume_id, limit: 36, null: false
      t.string :work_experience_id, limit: 36, null: false
      t.timestamps
    end

    add_index :resume_work_experiences, :user_id
    add_foreign_key :resume_work_experiences, :users, column: :user_id, primary_key: :id
    add_foreign_key :resume_work_experiences, :resumes, column: :resume_id, primary_key: :id
    add_foreign_key :resume_work_experiences, :work_experiences, column: :work_experience_id, primary_key: :id
  end
end
