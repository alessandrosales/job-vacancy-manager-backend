# frozen_string_literal: true

class ReferenceLink < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  validates :title, presence: true
  validates :url, presence: true

  def as_api_json
    as_json(only: %i[id user_id title url created_at updated_at])
  end
end
