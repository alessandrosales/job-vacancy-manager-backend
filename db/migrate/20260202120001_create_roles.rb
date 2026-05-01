# frozen_string_literal: true

class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :name, null: false
      t.text :description
      t.integer :interest_level, null: false, default: 0
      t.timestamps
    end

    add_index :roles, :user_id
    add_foreign_key :roles, :users, column: :user_id, primary_key: :id
  end
end
