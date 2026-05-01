# frozen_string_literal: true

class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :name, null: false
      t.string :url
      t.text :description
      t.integer :interest_level, null: false, default: 0
      t.timestamps
    end

    add_index :companies, :user_id
    add_foreign_key :companies, :users, column: :user_id, primary_key: :id
  end
end
