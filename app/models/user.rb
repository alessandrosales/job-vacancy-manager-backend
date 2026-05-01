class User < ApplicationRecord
  include UuidPrimaryKey

  has_secure_password

  has_many :roles, dependent: :destroy
  has_many :skills, dependent: :destroy

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
