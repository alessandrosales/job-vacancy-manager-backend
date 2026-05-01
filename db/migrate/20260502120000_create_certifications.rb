# frozen_string_literal: true

class CreateCertifications < ActiveRecord::Migration[8.1]
  def change
    create_table :certifications, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :name, null: false
      t.date :date_from
      t.date :date_to
      t.timestamps
    end

    add_index :certifications, :user_id
    add_foreign_key :certifications, :users, column: :user_id, primary_key: :id
  end
end
