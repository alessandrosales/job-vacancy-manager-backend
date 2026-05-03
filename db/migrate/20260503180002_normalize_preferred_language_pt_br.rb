# frozen_string_literal: true

class NormalizePreferredLanguagePtBr < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:users, :preferred_language)

    execute <<~SQL.squish
      UPDATE users SET preferred_language = 'pt_br' WHERE LOWER(TRIM(preferred_language)) = 'pt-br';
    SQL
  end

  def down
    return unless column_exists?(:users, :preferred_language)

    execute <<~SQL.squish
      UPDATE users SET preferred_language = 'pt-br' WHERE preferred_language = 'pt_br';
    SQL
  end
end
