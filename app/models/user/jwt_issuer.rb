# frozen_string_literal: true

# Stateless access tokens (HS256). Prefer +credentials+ (+jwt.secret+) or +JWT_SECRET+ in production.
class User::JwtIssuer
  class << self
    JWT_VERSION_CLAIM = "jv"

    def encode(user)
      payload = {
        "sub" => user.id,
        "exp" => token_ttl.from_now.to_i,
        JWT_VERSION_CLAIM => user.jwt_version
      }
      ::JWT.encode(payload, secret, "HS256", { typ: "JWT" })
    end

    def user_from_token(token)
      payload = ::JWT.decode(token, secret, true, { algorithm: "HS256" }).first

      token_version =
        if payload.key?(JWT_VERSION_CLAIM)
          raw = payload[JWT_VERSION_CLAIM]
          return nil unless raw.is_a?(Integer) || raw.to_s.match?(/\A\d+\z/)

          raw.to_i
        else
          # Tokens emitidos antes da claim `jv`: equivalente a versão 0; deixam de valer
          # assim que `user.jwt_version` subir (troca de senha / invalidate_jwt_sessions!).
          0
        end

      user = User.find_by(id: payload["sub"])
      return nil if user.nil?
      return nil if user.jwt_version != token_version

      user
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
