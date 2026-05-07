# frozen_string_literal: true

class AddAiTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :ai_token, :text
  end
end
