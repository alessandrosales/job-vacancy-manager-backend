# frozen_string_literal: true

class CreateResumeCertifications < ActiveRecord::Migration[8.1]
  def change
    create_table :resume_certifications, id: false, primary_key: %i[resume_id certification_id] do |t|
      t.string :user_id, limit: 36, null: false
      t.string :resume_id, limit: 36, null: false
      t.string :certification_id, limit: 36, null: false
      t.timestamps
    end

    add_index :resume_certifications, :user_id
    add_foreign_key :resume_certifications, :users, column: :user_id, primary_key: :id
    add_foreign_key :resume_certifications, :resumes, column: :resume_id, primary_key: :id
    add_foreign_key :resume_certifications, :certifications, column: :certification_id, primary_key: :id
  end
end
