# frozen_string_literal: true

class ResumeSkill < ApplicationRecord
  self.primary_key = %i[resume_id skill_id]

  belongs_to :user
  belongs_to :resume, touch: true
  belongs_to :skill

  validates :resume_id, uniqueness: { scope: :skill_id }

  validate :ownership_aligned

  private

  def ownership_aligned
    return if user_id.blank? || resume_id.blank? || skill_id.blank?

    res = resume
    sk = skill
    return if res.nil? || sk.nil?

    return if res.user_id == user_id && sk.user_id == user_id

    errors.add(:base, "resume and skill must belong to the same user as this link")
  end
end
