# frozen_string_literal: true

require "net/http"
require "json"

class User::FirebaseTokenVerifier
  class InvalidTokenError < StandardError; end

  GOOGLE_CERTS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
  ISSUER_PREFIX = "https://securetoken.google.com/"
  CLOCK_LEEWAY_SECONDS = 120

  class << self
    def verify_id_token(id_token)
      payload, = ::JWT.decode(id_token, nil, true, jwt_decode_options) do |header|
        certificate_for!(header.fetch("kid"))
      end

      validate_payload!(payload)
      payload
    rescue InvalidTokenError => e
      log_development_hints(id_token, e)
      raise e
    rescue KeyError, ::JWT::DecodeError, ::JWT::VerificationError => e
      log_development_hints(id_token, e)
      raise InvalidTokenError
    end

    private

    def jwt_decode_options
      {
        algorithm: "RS256",
        verify_iat: true,
        verify_expiration: true,
        exp_leeway: CLOCK_LEEWAY_SECONDS,
        iat_leeway: CLOCK_LEEWAY_SECONDS,
        verify_iss: true,
        iss: "#{ISSUER_PREFIX}#{firebase_project_id}",
        verify_aud: true,
        aud: firebase_project_id
      }
    end

    def validate_payload!(payload)
      raise InvalidTokenError if payload["sub"].to_s.blank?
      raise InvalidTokenError if payload["email"].to_s.blank?
      # Do not require `email_verified` here: Firebase still issues legitimate ID tokens for
      # email/password users before they complete verification; signature + aud/iss checks apply.
      raise InvalidTokenError unless payload["firebase"].is_a?(Hash)
    end

    def certificate_for!(kid)
      cert = certificates[kid]
      raise InvalidTokenError if cert.blank?

      OpenSSL::X509::Certificate.new(cert).public_key
    rescue OpenSSL::OpenSSLError
      raise InvalidTokenError
    end

    def certificates
      Rails.cache.fetch("firebase/google_certs", expires_in: 1.hour) do
        uri = URI(GOOGLE_CERTS_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 5

        response = http.request(Net::HTTP::Get.new(uri))
        raise InvalidTokenError unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      rescue JSON::ParserError
        raise InvalidTokenError
      end
    end

    def firebase_project_id
      ENV.fetch("FIREBASE_PROJECT_ID")
    rescue KeyError
      raise InvalidTokenError
    end

    # Helps debug 401 locally: malformed tokens, clock skew after leeway, or FIREBASE_PROJECT_ID != token `aud`.
    def log_development_hints(id_token, cause)
      return unless defined?(Rails) && Rails.env.development?

      Rails.logger.warn("[FirebaseTokenVerifier] rejected: #{cause.class}: #{cause.message}")
      Rails.logger.warn("[FirebaseTokenVerifier] FIREBASE_PROJECT_ID=#{ENV.fetch('FIREBASE_PROJECT_ID', nil).inspect}")

      decoded = ::JWT.decode(id_token.to_s.strip, nil, false)
      Rails.logger.warn(
        "[FirebaseTokenVerifier] unverified claims aud=#{decoded&.first&.[]('aud').inspect} " \
          "iss=#{decoded&.first&.[]('iss').inspect} firebase=#{decoded&.first&.[]('firebase').class}"
      )
    rescue ::JWT::DecodeError => e
      Rails.logger.warn("[FirebaseTokenVerifier] cannot decode for debug: #{e.class}: #{e.message}")
    end
  end
end
