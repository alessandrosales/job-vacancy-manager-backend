class User < ApplicationRecord
  include UuidPrimaryKey

  PREFERRED_UI_LANGUAGES = %w[en pt_br es].freeze

  has_secure_password

  generates_token_for :password_reset, expires_in: 2.hours do
    password_digest&.last(10)
  end

  has_many :roles, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :languages, dependent: :destroy
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
  before_validation :normalize_preferred_language
  before_save :bump_jwt_version_when_password_rotates

  validates :name, presence: true
  validates :email, presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :age,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 150 },
    allow_nil: true
  validates :preferred_language, inclusion: { in: PREFERRED_UI_LANGUAGES }

  class << self
    def find_or_create_from_firebase!(claims, preferred_language: nil)
      firebase_uid = claims.fetch("sub").to_s
      email = claims.fetch("email").to_s.strip.downcase
      name = claims["name"].presence || email.split("@").first

      user = find_by(firebase_uid: firebase_uid) || find_by(email: email) || User.new

      # Não importar `picture` do token Firebase: evita gravar URL externa e request da imagem no pós-login.
      user.assign_attributes(
        firebase_uid: firebase_uid,
        email: email,
        name: name
      )

      # Idioma escolhido na landing/login só vale na primeira persistência — evita sobrescrever
      # uma preferência já salva quando o usuário acessa de outra máquina/idioma.
      if user.new_record? && PREFERRED_UI_LANGUAGES.include?(preferred_language.to_s)
        user.preferred_language = preferred_language
      end

      if user.password_digest.blank?
        temporary_password = SecureRandom.hex(24)
        user.password = temporary_password
        user.password_confirmation = temporary_password
      end

      first_time_persist = user.new_record?
      user.save!
      if first_time_persist
        RegistrationMailer.with(user: user).welcome.deliver_now
      end
      user
    end
  end

  # Preferência da interface / e-mails transacionais → símbolo I18n (config/application.rb + config/locales/mailer.*.yml).
  def locale_for_mailer
    case preferred_language.to_s
    when "pt_br" then :"pt-BR"
    when "es" then :es
    else :en
    end
  end

  def as_api_json
    as_json(
      only: %i[
        id name email phone avatar_url bio age full_address relationship_status gender
        preferred_language
        created_at updated_at
      ]
    ).merge("ai_token_configured" => ai_token.present?)
  end

  # Incrementa +jwt_version+ para invalidar todos os JWTs emitidos antes (logout global).
  def invalidate_jwt_sessions!
    increment!(:jwt_version)
  end

  private

  def bump_jwt_version_when_password_rotates
    return unless password_digest_changed?
    return if new_record?

    self.jwt_version = jwt_version.to_i + 1
  end

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

  def normalize_preferred_language
    v = preferred_language.to_s.strip.downcase
    self.preferred_language = PREFERRED_UI_LANGUAGES.include?(v) ? v : "en"
  end
end
