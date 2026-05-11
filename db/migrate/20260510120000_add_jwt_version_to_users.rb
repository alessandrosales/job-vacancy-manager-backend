# frozen_string_literal: true

class AddJwtVersionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :jwt_version, :integer, null: false, default: 0
  end
end
