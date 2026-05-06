# frozen_string_literal: true

class WorkExperience < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  has_many :work_experience_skills, dependent: :destroy
  has_many :skills, through: :work_experience_skills
  has_many :resume_work_experiences, dependent: :destroy
  has_many :resumes, through: :resume_work_experiences

  attribute :is_remote, :boolean, default: false

  validates :title, presence: true
  validates :company_name, presence: true
  validates :is_remote, inclusion: { in: [ true, false ] }

  def as_api_json
    ids = work_experience_skills.order(created_at: :asc).pluck(:skill_id)
    as_json(only: %i[id user_id title description company_name is_remote date_from date_to created_at updated_at]).merge(
      "skill_ids" => ids
    )
  end

  # Replaces all skill links. +skill_ids_raw+ may be empty (clear links). Every id must belong to +user+.
  def sync_skill_links!(user, skill_ids_raw)
    ids = normalize_sync_id_list(skill_ids_raw)
    return false unless user.skills.where(id: ids).count == ids.size

    transaction do
      work_experience_skills.destroy_all
      ids.each do |skill_id|
        work_experience_skills.create!(skill_id: skill_id, user_id: user.id)
      end
    end
    true
  end

  private

  def normalize_sync_id_list(raw)
    Array(raw).map(&:presence).compact.uniq
  end
end
