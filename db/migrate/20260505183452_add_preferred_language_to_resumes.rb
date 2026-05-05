# frozen_string_literal: true

class AddPreferredLanguageToResumes < ActiveRecord::Migration[8.1]
  def change
    add_column :resumes, :preferred_language, :string, null: false, default: "en"
  end
end
