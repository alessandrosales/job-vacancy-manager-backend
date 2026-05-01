# frozen_string_literal: true

# Stateless access tokens (HS256). Prefer +credentials+ (+jwt.secret+) or +JWT_SECRET+ in production.
class User::JwtIssuer
  class << self
    def encode(user)
      payload = { "sub" => user.id, "exp" => token_ttl.from_now.to_i }
      ::JWT.encode(payload, secret, "HS256", { typ: "JWT" })
    end

    def user_from_token(token)
      payload = ::JWT.decode(token, secret, true, { algorithm: "HS256" }).first
      User.find_by(id: payload["sub"])
    rescue ::JWT::DecodeError, ::JWT::ExpiredSignature
      nil
    end

    def token_ttl
      24.hours
    end

    private

    def secret
      Rails.application.credentials.dig(:jwt, :secret).presence ||
        ENV["JWT_SECRET"].presence ||
        Rails.application.secret_key_base
    end
  end
end
