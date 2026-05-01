class User < ApplicationRecord
  has_secure_password

  before_validation :normalize_email
  before_create :assign_uuid

  validates :name, presence: true
  validates :email, presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  def as_api_json
    as_json(only: %i[id name email created_at updated_at])
  end

  private

  def assign_uuid
    self.id = SecureRandom.uuid if id.blank?
  end

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end
