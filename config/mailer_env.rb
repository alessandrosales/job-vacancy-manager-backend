# frozen_string_literal: true

# Deriva URLs e remetente padrão dos e-mails a partir de +FRONTEND_URL+ (+SMTP_*+),
# com opt-in opcional das variáveis legadas MAILER_*.
#
# Vive em config/ para carregar antes das environment files (+MailerEnv+ é referenciado em production.rb/development.rb).
module MailerEnv
  module_function

  # Remetente transacional — prefer SMTP_DEFAULT_FROM, depois MAILER_DEFAULT_FROM.
  def transactional_from
    ENV["SMTP_DEFAULT_FROM"].presence || ENV["MAILER_DEFAULT_FROM"].presence
  end

  # Opções usadas pelo Action Mailer em +default_url_helpers+ dentro de templates.
  def action_mailer_default_url_options
    return legacy_action_mailer_url_options if ENV["MAILER_DEFAULT_URL_HOST"].present?

    opts = frontend_url_default_options
    return opts if opts[:host].present?

    fallback_action_mailer_url_options
  end

  # Domínio HELO/EHLO em SMTP quando +SMTP_DOMAIN+ não está definido.
  def smtp_helo_domain
    ENV["SMTP_DOMAIN"].presence ||
      host_from_frontend_url ||
      ENV["MAILER_DEFAULT_URL_HOST"].presence ||
      "localhost"
  end

  def legacy_action_mailer_url_options
    {
      host: ENV.fetch("MAILER_DEFAULT_URL_HOST"),
      protocol: ENV.fetch(
        "MAILER_DEFAULT_URL_PROTOCOL",
        Rails.env.production? ? "https" : "http"
      ),
      port: ENV["MAILER_DEFAULT_URL_PORT"].presence&.to_i
    }.compact
  end

  def frontend_url_default_options
    raw = ENV["FRONTEND_URL"].to_s.strip.chomp("/")
    return {} if raw.blank?

    uri = coerce_http_uri(raw)
    return {} unless uri&.scheme&.match?(/\Ahttps?\z/)

    out = {
      host: uri.host,
      protocol: uri.scheme || (Rails.env.production? ? "https" : "http")
    }
    port = uri.port if uri.respond_to?(:port)
    out[:port] = port if port.present? && !default_uri_port?(uri.scheme, port)
    out.compact
  rescue URI::InvalidURIError
    {}
  end

  def host_from_frontend_url
    frontend_url_default_options[:host]
  end

  def coerce_http_uri(raw)
    uri = URI.parse(raw)
    return uri if uri.is_a?(URI::HTTP)

    URI.parse("https://#{raw}")
  end

  def default_uri_port?(scheme, port)
    (scheme.to_s == "https" && port == 443) ||
      (scheme.to_s == "http" && port == 80)
  end

  def fallback_action_mailer_url_options
    case Rails.env
    when "production"
      { host: "example.com", protocol: "https" }
    when "test"
      { host: "example.com" }
    else
      { host: "localhost", port: 3000 }
    end
  end
end
