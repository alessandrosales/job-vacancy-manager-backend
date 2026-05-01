# frozen_string_literal: true

# SMTP a partir de +Rails.application.credentials+ (:smtp, :mailer) ou variáveis de ambiente.
# ENV tem prioridade sobre credentials (útil no Docker/Kamal).
#
# Em +bin/rails credentials:edit+, use o bloco exemplificado em:
#   config/credentials/smtp.example.yml
#
# Ambiente de teste: permanece :test (config/environments/test.rb).
return if Rails.env.test?

smtp_cred = (Rails.application.credentials.dig(:smtp) || {}).with_indifferent_access
mailer_cred = (Rails.application.credentials.dig(:mailer) || {}).with_indifferent_access

smtp_address = ENV["SMTP_ADDRESS"].presence || smtp_cred[:address].presence
return if smtp_address.blank?

Rails.application.configure do
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true

  from = ENV["MAILER_DEFAULT_FROM"].presence || mailer_cred[:default_from].presence
  config.action_mailer.default_options = { from: from } if from.present?

  auth_mode = (ENV["SMTP_AUTHENTICATION"].presence || smtp_cred[:authentication].presence || "plain").to_s.downcase.strip

  port_src = ENV["SMTP_PORT"].presence || smtp_cred[:port]
  port = port_src.present? ? port_src.to_i : 587

  domain = ENV["SMTP_DOMAIN"].presence || smtp_cred[:domain].presence ||
    ENV["MAILER_DEFAULT_URL_HOST"].presence || mailer_cred[:default_url_host].presence ||
    "localhost"

  starttls_env = ENV["SMTP_ENABLE_STARTTLS_AUTO"]
  enable_starttls = if starttls_env.nil?
    if smtp_cred.key?(:enable_starttls_auto)
      ActiveModel::Type::Boolean.new.cast(smtp_cred[:enable_starttls_auto])
    else
      true
    end
  else
    ActiveModel::Type::Boolean.new.cast(starttls_env)
  end

  ssl_env = ENV["SMTP_SSL"]
  ssl = if ssl_env.nil?
    ActiveModel::Type::Boolean.new.cast(smtp_cred[:ssl])
  else
    ActiveModel::Type::Boolean.new.cast(ssl_env)
  end

  settings = {
    address: smtp_address,
    port: port,
    domain: domain,
    enable_starttls_auto: enable_starttls
  }

  if auth_mode.present? && auth_mode != "none"
    user = ENV["SMTP_USER_NAME"].presence || smtp_cred[:user_name].presence
    password = ENV["SMTP_PASSWORD"].presence || smtp_cred[:password].presence
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
