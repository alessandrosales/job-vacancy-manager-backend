# frozen_string_literal: true

class Role < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  has_many :opportunities, dependent: :restrict_with_error
  has_many :resumes, dependent: :restrict_with_error

  before_validation :normalize_name

  validates :name, presence: true
  validates :name,
    uniqueness: {
      scope: :user_id,
      case_sensitive: false
    }
  validates :interest_level, inclusion: { in: 0..5 }, numericality: { only_integer: true }

  def as_api_json
    as_json(only: %i[id user_id name description interest_level created_at updated_at])
  end

  private

  def normalize_name
    self.name = name.to_s.strip
  end
end
