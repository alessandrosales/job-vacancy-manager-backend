# frozen_string_literal: true

class Resume < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user
  belongs_to :role

  has_many :resume_work_experiences, dependent: :destroy
  has_many :work_experiences, through: :resume_work_experiences
  has_many :resume_certifications, dependent: :destroy
  has_many :certifications, through: :resume_certifications
  has_many :resume_educations, dependent: :destroy
  has_many :educations, through: :resume_educations
  has_many :resume_skills, dependent: :destroy
  has_many :skills, through: :resume_skills

  validates :title, presence: true
  validate :role_owned_by_user

  def as_api_json
    as_json(only: %i[id user_id role_id title description created_at updated_at])
  end

  def sync_work_experience_links!(user, ids_raw)
    replace_resume_joins(:resume_work_experiences, :work_experience_id, user, ids_raw, user.work_experiences)
  end

  def sync_certification_links!(user, ids_raw)
    replace_resume_joins(:resume_certifications, :certification_id, user, ids_raw, user.certifications)
  end

  def sync_education_links!(user, ids_raw)
    replace_resume_joins(:resume_educations, :education_id, user, ids_raw, user.educations)
  end

  def sync_skill_links!(user, ids_raw)
    replace_resume_joins(:resume_skills, :skill_id, user, ids_raw, user.skills)
  end

  private

  def replace_resume_joins(join_assoc, fk_column, user, ids_raw, owned_scope)
    ids = normalize_sync_id_list(ids_raw)
    return false unless owned_scope.where(id: ids).count == ids.size

    transaction do
      send(join_assoc).destroy_all
      ids.each do |foreign_id|
        send(join_assoc).create!(fk_column => foreign_id, user_id: user.id)
      end
    end
    true
  end

  def normalize_sync_id_list(raw)
    Array(raw).map(&:presence).compact.uniq
  end

  def role_owned_by_user
    return if role_id.blank? || user_id.blank?

    errors.add(:role_id, "is invalid") unless Role.exists?(id: role_id, user_id: user_id)
  end
end
