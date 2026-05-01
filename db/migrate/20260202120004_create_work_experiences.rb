# frozen_string_literal: true

class CreateWorkExperiences < ActiveRecord::Migration[8.1]
  def change
    create_table :work_experiences, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :title, null: false
      t.string :company_name, null: false
      t.boolean :is_remote, null: false, default: false
      t.date :date_from
      t.date :date_to
      t.timestamps
    end

    add_index :work_experiences, :user_id
    add_foreign_key :work_experiences, :users, column: :user_id, primary_key: :id
  end
end
