# frozen_string_literal: true

class CreateOpportunities < ActiveRecord::Migration[8.1]
  def change
    create_table :opportunities, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :company_id, limit: 36, null: false
      t.string :role_id, limit: 36, null: false
      t.text :description
      t.string :url
      t.string :status_id, limit: 36, null: false
      t.integer :interest_level, null: false, default: 0
      t.decimal :hourly_rate, precision: 12, scale: 2
      t.decimal :annual_salary, precision: 14, scale: 2
      t.timestamps
    end

    add_index :opportunities, :user_id
    add_index :opportunities, :company_id
    add_index :opportunities, :role_id
    add_index :opportunities, :status_id

    add_foreign_key :opportunities, :users, column: :user_id, primary_key: :id
    add_foreign_key :opportunities, :companies, column: :company_id, primary_key: :id
    add_foreign_key :opportunities, :roles, column: :role_id, primary_key: :id
    add_foreign_key :opportunities, :opportunity_statuses, column: :status_id, primary_key: :id
  end
end
