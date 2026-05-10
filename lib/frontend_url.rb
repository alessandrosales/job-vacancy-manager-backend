# frozen_string_literal: true

# Base URL of the SPA used in transactional e-mails (password reset links, etc.).
# Set +ENV["FRONTEND_URL"]+ (string, no trailing slash); see +.env.example+.
# Action Mailer +default_url_options+ also align with +FRONTEND_URL+ when legacy MAILER_* envs are unset (see +config/mailer_env.rb+).
# In non-production, falls back to +http://localhost:5173+ when unset so local mail previews work.
module FrontendUrl
  class MissingFrontendUrlError < StandardError; end

  RESET_PASSWORD_PATH = "reset-password"

  class << self
    def base
      url = ENV["FRONTEND_URL"].to_s.strip.chomp("/")
      return url if url.present?
      return "http://localhost:5173" unless Rails.env.production?

      raise MissingFrontendUrlError,
        "Set ENV['FRONTEND_URL'] for password reset links (see .env.example)"
    end

    def password_reset_link(reset_token)
      root = base
      uri = URI.join("#{root}/", RESET_PASSWORD_PATH)
      uri.query = URI.encode_www_form("reset_token" => reset_token.to_s)
      uri.to_s
    end
  end
end
