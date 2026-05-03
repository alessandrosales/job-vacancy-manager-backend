# frozen_string_literal: true

# SMTP from environment variables (see .env.example). Used in development and production.
#
# Ambiente de teste: permanece :test (config/environments/test.rb).
return if Rails.env.test?

smtp_address = ENV["SMTP_ADDRESS"].presence
return if smtp_address.blank?

Rails.application.configure do
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true

  from = ENV["MAILER_DEFAULT_FROM"].presence
  config.action_mailer.default_options = { from: from } if from.present?

  auth_mode = (ENV["SMTP_AUTHENTICATION"].presence || "plain").to_s.downcase.strip

  port = ENV["SMTP_PORT"].present? ? ENV["SMTP_PORT"].to_i : 587

  domain = ENV["SMTP_DOMAIN"].presence ||
    ENV["MAILER_DEFAULT_URL_HOST"].presence ||
    "localhost"

  enable_starttls = ActiveModel::Type::Boolean.new.cast(
    ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true")
  )

  ssl = ActiveModel::Type::Boolean.new.cast(ENV.fetch("SMTP_SSL", "false"))

  settings = {
    address: smtp_address,
    port: port,
    domain: domain,
    enable_starttls_auto: enable_starttls
  }

  if auth_mode.present? && auth_mode != "none"
    user = ENV["SMTP_USER_NAME"].presence
    password = ENV["SMTP_PASSWORD"].presence
    if user.present?
      settings[:authentication] = auth_mode.to_sym
      settings[:user_name] = user
      settings[:password] = password if password.present?
    end
  end

  settings[:ssl] = true if ssl

  config.action_mailer.smtp_settings = settings.compact

  if Rails.env.development? && ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("MAILER_RAISE_DELIVERY_ERRORS", "true")
    )
    config.action_mailer.raise_delivery_errors = true
  end
end
