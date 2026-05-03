# frozen_string_literal: true

# Languages the user speaks (reference data, same ownership pattern as roles/skills).
class CreateLanguages < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:languages)

    create_table :languages, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :name, null: false
      t.string :level, null: false
      t.timestamps
    end

    add_index :languages, :user_id
    add_foreign_key :languages, :users, column: :user_id, primary_key: :id
  end

  def down
    drop_table :languages if table_exists?(:languages)
  end
end
