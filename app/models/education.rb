# frozen_string_literal: true

class Education < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  has_many :resume_educations, dependent: :destroy
  has_many :resumes, through: :resume_educations

  validates :institution_name, presence: true
  validate :date_range_consistent

  def as_api_json
    as_json(only: %i[id user_id institution_name degree field_of_study date_from date_to created_at updated_at])
  end

  private

  def date_range_consistent
    return if date_from.blank? || date_to.blank?

    errors.add(:date_to, :invalid_date_range) if date_to < date_from
  end
end
