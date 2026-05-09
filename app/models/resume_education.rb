# frozen_string_literal: true

class ResumeEducation < ApplicationRecord
  self.primary_key = %i[resume_id education_id]

  belongs_to :user
  belongs_to :resume, touch: true
  belongs_to :education

  validates :resume_id, uniqueness: { scope: :education_id }

  validate :ownership_aligned

  private

  def ownership_aligned
    return if user_id.blank? || resume_id.blank? || education_id.blank?

    res = resume
    edu = education
    return if res.nil? || edu.nil?

    return if res.user_id == user_id && edu.user_id == user_id

    errors.add(:base, :ownership_mismatch)
  end
end
