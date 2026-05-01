# frozen_string_literal: true

class Skill < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  has_many :work_experience_skills, dependent: :destroy
  has_many :work_experiences, through: :work_experience_skills
  has_many :resume_skills, dependent: :destroy
  has_many :resumes, through: :resume_skills

  validates :name, presence: true

  def as_api_json
    as_json(only: %i[id user_id name description created_at updated_at])
  end
end
