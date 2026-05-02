# frozen_string_literal: true

class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :phone
      t.string :avatar_url
      t.text :bio
      t.integer :age
      t.text :full_address
      t.string :relationship_status
      t.string :gender
    end
  end
end
