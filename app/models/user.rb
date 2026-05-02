class User < ApplicationRecord
  include UuidPrimaryKey

  has_secure_password

  generates_token_for :password_reset, expires_in: 2.hours do
    password_digest&.last(10)
  end

  has_many :roles, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :reference_links, dependent: :destroy
  has_many :work_experiences, dependent: :destroy
  has_many :certifications, dependent: :destroy
  has_many :educations, dependent: :destroy
  has_many :companies, dependent: :destroy
  has_many :opportunity_statuses, dependent: :destroy
  has_many :opportunities, dependent: :destroy
  has_many :resumes, dependent: :destroy

  before_validation :normalize_email
  before_validation :normalize_optional_profile_fields

  validates :name, presence: true
  validates :email, presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :age,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 150 },
    allow_nil: true

  def as_api_json
    as_json(
      only: %i[
        id name email phone avatar_url bio age full_address relationship_status gender
        created_at updated_at
      ]
    )
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end

  def normalize_optional_profile_fields
    %i[phone avatar_url bio full_address relationship_status gender].each do |attr|
      val = self[attr]
      next if val.nil?

      self[attr] = val.to_s.strip.presence
    end
  end
end
