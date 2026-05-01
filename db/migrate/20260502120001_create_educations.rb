# frozen_string_literal: true

class CreateEducations < ActiveRecord::Migration[8.1]
  def change
    create_table :educations, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :user_id, limit: 36, null: false
      t.string :institution_name, null: false
      t.string :degree
      t.string :field_of_study
      t.date :date_from
      t.date :date_to
      t.timestamps
    end

    add_index :educations, :user_id
    add_foreign_key :educations, :users, column: :user_id, primary_key: :id
  end
end
