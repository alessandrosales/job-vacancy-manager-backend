# frozen_string_literal: true

module Api
  module V1
    module Auth
      class FirebaseSessionsController < BaseController
        def create
          id_token = params.require(:auth).permit(:id_token).fetch(:id_token).to_s.strip
          claims = User::FirebaseTokenVerifier.verify_id_token(id_token)
          user = User.find_or_create_from_firebase!(claims)

          render json: {
            token: User::JwtIssuer.encode(user),
            user: user.as_api_json
          }, status: :ok
        rescue User::FirebaseTokenVerifier::InvalidTokenError
          head :unauthorized
        rescue ActionController::ParameterMissing
          head :unprocessable_entity
        end
      end
    end
  end
end
