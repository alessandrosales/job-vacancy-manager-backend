# frozen_string_literal: true

# String PK (36 chars) compatible with SQLite + OpenAPI UUID contract.
module UuidPrimaryKey
  extend ActiveSupport::Concern

  included do
    before_create :assign_uuid_id
  end

  private

  def assign_uuid_id
    self.id = SecureRandom.uuid if id.blank?
  end
end
