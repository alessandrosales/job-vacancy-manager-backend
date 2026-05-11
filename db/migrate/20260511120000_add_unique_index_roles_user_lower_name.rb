# frozen_string_literal: true

class AddUniqueIndexRolesUserLowerName < ActiveRecord::Migration[8.1]
  def change
    add_index :roles, "user_id, lower(name)",
      unique: true,
      name: "index_roles_on_user_id_lower_name_unique"
  end
end
