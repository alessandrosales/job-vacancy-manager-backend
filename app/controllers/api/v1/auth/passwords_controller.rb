# frozen_string_literal: true

module Api
  module V1
    module Auth
      class PasswordsController < BaseController
        def recover
          email = recover_params[:email].to_s.strip.downcase
          user = User.find_by(email: email) if email.present?
          if user
            unless ActionMailer::Base.perform_deliveries
              Rails.logger.warn(
                "[PasswordsController#recover] user matched but ActionMailer.perform_deliveries is false — " \
                "no e-mail sent (set SMTP_ADDRESS in the Rails process env; see config/environments/production.rb)."
              )
            end
            token = user.generate_token_for(:password_reset)
            PasswordMailer.with(user: user, token: token).reset_instructions.deliver_now
          end
          head :no_content
        end

        def change
          attrs = change_params
          user = User.find_by_token_for(:password_reset, attrs[:reset_token].to_s)
          if user.nil?
            render json: {
              errors: { reset_token: [ I18n.t("api.errors.auth.reset_token_invalid") ] }
            }, status: :unprocessable_entity
            return
          end

          user.password = attrs[:password]
          user.password_confirmation = attrs[:password_confirmation]
          if user.save
            PasswordMailer.with(user: user).password_changed.deliver_now
            render json: {
              token: User::JwtIssuer.encode(user),
              user: user.as_api_json
            }, status: :ok
          else
            render json: { errors: user.errors.as_json }, status: :unprocessable_entity
          end
        end

        private

        def recover_params
          params.fetch(:auth, ActionController::Parameters.new).permit(:email)
        end

        def change_params
          params.fetch(:auth, ActionController::Parameters.new).permit(:reset_token, :password, :password_confirmation)
        end
      end
    end
  end
end
