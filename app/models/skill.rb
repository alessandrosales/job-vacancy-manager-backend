# frozen_string_literal: true

class Skill < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  validates :name, presence: true

  def as_api_json
    as_json(only: %i[id user_id name description created_at updated_at])
  end
end
