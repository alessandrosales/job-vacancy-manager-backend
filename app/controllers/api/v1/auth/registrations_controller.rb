# frozen_string_literal: true

module Api
  module V1
    module Auth
      class RegistrationsController < BaseController
        def create
          user = User.new(registration_params)
          if user.save
            RegistrationMailer.with(user: user).welcome.deliver_now
            render json: {
              token: User::JwtIssuer.encode(user),
              user: user.as_api_json
            }, status: :created
          else
            render json: { errors: user.errors.as_json }, status: :unprocessable_entity
          end
        end

        private

        def registration_params
          params.require(:auth).permit(:name, :email, :password, :password_confirmation)
        end
      end
    end
  end
end
