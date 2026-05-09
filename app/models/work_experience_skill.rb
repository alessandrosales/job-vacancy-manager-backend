# frozen_string_literal: true

class WorkExperienceSkill < ApplicationRecord
  self.primary_key = %i[work_experience_id skill_id]

  belongs_to :user
  belongs_to :work_experience
  belongs_to :skill

  validates :work_experience_id, uniqueness: { scope: :skill_id }

  validate :ownership_aligned

  private

  def ownership_aligned
    return if user_id.blank? || work_experience_id.blank? || skill_id.blank?

    we = work_experience
    sk = skill
    return if we.nil? || sk.nil?

    return if we.user_id == user_id && sk.user_id == user_id

    errors.add(:base, :ownership_mismatch)
  end
end
