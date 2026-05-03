# frozen_string_literal: true

class Language < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  LEVELS = %w[beginner intermediate advanced native].freeze

  validates :name, presence: true
  validates :level, presence: true, inclusion: { in: LEVELS }

  def as_api_json
    as_json(only: %i[id user_id name level created_at updated_at])
  end
end
