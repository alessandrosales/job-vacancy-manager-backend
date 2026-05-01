# frozen_string_literal: true

class CreateResumeEducations < ActiveRecord::Migration[8.1]
  def change
    create_table :resume_educations, id: false, primary_key: %i[resume_id education_id] do |t|
      t.string :user_id, limit: 36, null: false
      t.string :resume_id, limit: 36, null: false
      t.string :education_id, limit: 36, null: false
      t.timestamps
    end

    add_index :resume_educations, :user_id
    add_foreign_key :resume_educations, :users, column: :user_id, primary_key: :id
    add_foreign_key :resume_educations, :resumes, column: :resume_id, primary_key: :id
    add_foreign_key :resume_educations, :educations, column: :education_id, primary_key: :id
  end
end
