# frozen_string_literal: true

# Base URL of the SPA used in transactional e-mails (password reset links, etc.).
# Set +Rails.application.credentials[:frontend_url]+ (string, no trailing slash) or +ENV["FRONTEND_URL"]+.
# In non-production, falls back to +http://localhost:5173+ when unset so local mail previews work.
module FrontendUrl
  class MissingFrontendUrlError < StandardError; end

  RESET_PASSWORD_PATH = "reset-password"

  class << self
    def base
      url = Rails.application.credentials[:frontend_url].presence ||
        ENV["FRONTEND_URL"].presence
      url = url.to_s.strip.chomp("/")
      return url if url.present?
      return "http://localhost:5173" unless Rails.env.production?

      raise MissingFrontendUrlError,
        "Set credentials[:frontend_url] or ENV['FRONTEND_URL'] for password reset links"
    end

    def password_reset_link(reset_token)
      root = base
      uri = URI.join("#{root}/", RESET_PASSWORD_PATH)
      uri.query = URI.encode_www_form("reset_token" => reset_token.to_s)
      uri.to_s
    end
  end
end
