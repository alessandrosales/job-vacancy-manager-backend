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

  validates :name, presence: true
  validates :email, presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  def as_api_json
    as_json(only: %i[id name email created_at updated_at])
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end
