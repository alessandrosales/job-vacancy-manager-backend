# frozen_string_literal: true

class CreateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    add_index :skills, :user_id
    add_foreign_key :skills, :users, column: :user_id, primary_key: :id
  end
end
