# frozen_string_literal: true

class CreateOpportunityStatuses < ActiveRecord::Migration[8.1]
  def change
    create_table :opportunity_statuses, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :label, null: false
      t.text :description
      t.string :variant, null: false
      t.integer :position
      t.timestamps
    end

    add_index :opportunity_statuses, :user_id
    add_foreign_key :opportunity_statuses, :users, column: :user_id, primary_key: :id
  end
end
