# frozen_string_literal: true

class Company < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user
  has_many :opportunities, dependent: :restrict_with_error

  validates :name, presence: true
  validates :interest_level, inclusion: { in: 0..5 }, numericality: { only_integer: true }
end
