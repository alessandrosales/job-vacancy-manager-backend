# frozen_string_literal: true

class AddFirebaseUidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :firebase_uid, :string
    add_index :users, :firebase_uid, unique: true, where: "firebase_uid IS NOT NULL"
  end
end
