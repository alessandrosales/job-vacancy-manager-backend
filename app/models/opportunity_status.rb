# frozen_string_literal: true

class OpportunityStatus < ApplicationRecord
  include UuidPrimaryKey

  BADGE_VARIANTS = %w[secondary outline default destructive].freeze

  belongs_to :user
  has_many :opportunities, foreign_key: :status_id, dependent: :restrict_with_error, inverse_of: :opportunity_status

  validates :label, presence: true
  validates :variant, presence: true, inclusion: { in: BADGE_VARIANTS }

  def as_api_json
    as_json(only: %i[id user_id label description variant position created_at updated_at])
  end
end
