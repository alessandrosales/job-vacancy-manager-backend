# frozen_string_literal: true

class CreateReferenceLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :reference_links, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.timestamps
    end

    add_index :reference_links, :user_id
    add_foreign_key :reference_links, :users, column: :user_id, primary_key: :id
  end
end
