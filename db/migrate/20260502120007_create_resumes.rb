# frozen_string_literal: true

class CreateResumes < ActiveRecord::Migration[8.1]
  def change
    create_table :resumes, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :title, null: false
      t.text :description
      t.string :role_id, limit: 36, null: false
      t.timestamps
    end

    add_index :resumes, :user_id
    add_index :resumes, :role_id

    add_foreign_key :resumes, :users, column: :user_id, primary_key: :id
    add_foreign_key :resumes, :roles, column: :role_id, primary_key: :id
  end
end
