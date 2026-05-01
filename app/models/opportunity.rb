# frozen_string_literal: true

class Opportunity < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user
  belongs_to :company
  belongs_to :role
  belongs_to :opportunity_status, foreign_key: :status_id, inverse_of: :opportunities

  validates :interest_level, inclusion: { in: 0..5 }, numericality: { only_integer: true }
  validates :hourly_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :annual_salary, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :scoped_associations_owned_by_user

  def as_api_json
    as_json(
      only: %i[
        id user_id company_id role_id description url status_id interest_level
        hourly_rate annual_salary created_at updated_at
      ]
    ).tap do |h|
      h["hourly_rate"] = hourly_rate.to_f if hourly_rate.present?
      h["annual_salary"] = annual_salary.to_f if annual_salary.present?
    end
  end

  private

  def scoped_associations_owned_by_user
    uid = user_id
    return if uid.blank?

    validate_record_owned(Company, company_id, :company_id, uid)
    validate_record_owned(Role, role_id, :role_id, uid)
    validate_record_owned(OpportunityStatus, status_id, :status_id, uid)
  end

  def validate_record_owned(model, fk_value, error_key, uid)
    return if fk_value.blank?

    errors.add(error_key, "is invalid") unless model.exists?(id: fk_value, user_id: uid)
  end
end
