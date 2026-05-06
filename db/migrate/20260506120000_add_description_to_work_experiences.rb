# frozen_string_literal: true

class AddDescriptionToWorkExperiences < ActiveRecord::Migration[8.1]
  def change
    add_column :work_experiences, :description, :text
  end
end
