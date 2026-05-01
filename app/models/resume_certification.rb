# frozen_string_literal: true

class ResumeCertification < ApplicationRecord
  self.primary_key = %i[resume_id certification_id]

  belongs_to :user
  belongs_to :resume, touch: true
  belongs_to :certification

  validates :resume_id, uniqueness: { scope: :certification_id }

  validate :ownership_aligned

  private

  def ownership_aligned
    return if user_id.blank? || resume_id.blank? || certification_id.blank?

    res = resume
    cert = certification
    return if res.nil? || cert.nil?

    return if res.user_id == user_id && cert.user_id == user_id

    errors.add(:base, "resume and certification must belong to the same user as this link")
  end
end
