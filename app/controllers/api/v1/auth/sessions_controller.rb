# frozen_string_literal: true

module Api
  module V1
    module Auth
      class SessionsController < BaseController
        def create
          creds = params.require(:auth).permit(:email, :password)
          user = User.find_by(email: creds[:email].to_s.strip.downcase)
          if user&.authenticate(creds[:password])
            render json: {
              token: User::JwtIssuer.encode(user),
              user: user.as_api_json
            }, status: :ok
          else
            head :unauthorized
          end
        end
      end
    end
  end
end
