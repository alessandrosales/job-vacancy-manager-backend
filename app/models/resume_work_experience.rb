# frozen_string_literal: true

class ResumeWorkExperience < ApplicationRecord
  self.primary_key = %i[resume_id work_experience_id]

  belongs_to :user
  belongs_to :resume, touch: true
  belongs_to :work_experience

  validates :resume_id, uniqueness: { scope: :work_experience_id }

  validate :ownership_aligned

  private

  def ownership_aligned
    return if user_id.blank? || resume_id.blank? || work_experience_id.blank?

    res = resume
    we = work_experience
    return if res.nil? || we.nil?

    return if res.user_id == user_id && we.user_id == user_id

    errors.add(:base, "resume and work_experience must belong to the same user as this link")
  end
end
