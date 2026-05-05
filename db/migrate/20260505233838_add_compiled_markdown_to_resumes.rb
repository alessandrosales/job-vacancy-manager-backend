# frozen_string_literal: true

class AddCompiledMarkdownToResumes < ActiveRecord::Migration[8.1]
  def change
    add_column :resumes, :compiled_markdown, :text, null: true
  end
end
