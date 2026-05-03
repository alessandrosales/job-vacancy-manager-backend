# frozen_string_literal: true

# UI / e-mail locale preference: en | pt_br | es (see User::PREFERRED_UI_LANGUAGES).
class AddPreferredLanguageToUsers < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:users, :preferred_language)

    add_column :users, :preferred_language, :string, null: false, default: "en"
  end

  def down
    remove_column :users, :preferred_language if column_exists?(:users, :preferred_language)
  end
end
