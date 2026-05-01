# frozen_string_literal: true

class Role < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  validates :name, presence: true
  validates :interest_level, inclusion: { in: 0..5 }, numericality: { only_integer: true }

  def as_api_json
    as_json(only: %i[id user_id name description interest_level created_at updated_at])
  end
end
