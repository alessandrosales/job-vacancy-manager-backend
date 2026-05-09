# frozen_string_literal: true

class Resume < ApplicationRecord
  include UuidPrimaryKey

  PREFERRED_LANGUAGES = %w[en pt_br es].freeze

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

  before_validation :normalize_preferred_language_column

  validates :title, presence: true
  validates :preferred_language, inclusion: { in: PREFERRED_LANGUAGES }
  validate :role_owned_by_user

  def self.normalize_preferred_language(raw)
    s = raw.to_s.strip.downcase.tr("-", "_")
    PREFERRED_LANGUAGES.include?(s) ? s : "en"
  end

  def as_api_json
    as_json(
      only: %i[id user_id role_id title description preferred_language compiled_markdown created_at updated_at]
    ).merge(
      "work_experience_ids" => sorted_join_foreign_ids(:resume_work_experiences, :work_experience_id),
      "certification_ids" => sorted_join_foreign_ids(:resume_certifications, :certification_id),
      "education_ids" => sorted_join_foreign_ids(:resume_educations, :education_id),
      "skill_ids" => sorted_join_foreign_ids(:resume_skills, :skill_id)
    )
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

  def duplicate_for_user!(user:)
    transaction do
      copy = user.resumes.create!(
        title: duplicated_title,
        description: description,
        role_id: role_id,
        preferred_language: preferred_language,
        compiled_markdown: compiled_markdown
      )

      copy_join_rows!(copy, :resume_work_experiences, :work_experience_id)
      copy_join_rows!(copy, :resume_certifications, :certification_id)
      copy_join_rows!(copy, :resume_educations, :education_id)
      copy_join_rows!(copy, :resume_skills, :skill_id)

      copy
    end
  end

  private

  def duplicated_title
    base = title.to_s.strip
    return "Untitled (Copy)" if base.blank?

    "#{base} (Copy)"
  end

  def copy_join_rows!(copy, join_assoc, fk_column)
    send(join_assoc).order(:created_at, fk_column).find_each do |join_row|
      copy.public_send(join_assoc).create!(
        fk_column => join_row.public_send(fk_column),
        user_id: copy.user_id
      )
    end
  end

  def normalize_preferred_language_column
    self.preferred_language = Resume.normalize_preferred_language(preferred_language)
  end

  def sorted_join_foreign_ids(join_assoc, fk_column)
    send(join_assoc).sort_by do |row|
      [ row.created_at, row.public_send(fk_column).to_s ]
    end.map { |row| row.public_send(fk_column) }
  end

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

    errors.add(:role_id, :invalid) unless Role.exists?(id: role_id, user_id: user_id)
  end
end
