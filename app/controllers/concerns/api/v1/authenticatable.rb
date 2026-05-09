# frozen_string_literal: true

module Api
  module V1
    module Authenticatable
      extend ActiveSupport::Concern

      included do
        # Runs before sibling before_actions such as locale resolution → Current.user present.
        prepend_before_action :authenticate_request!
        after_action :clear_current_user
      end

      private

      def authenticate_request!
        token = bearer_token
        if token.blank?
          head :unauthorized
          return
        end

        user = User::JwtIssuer.user_from_token(token)
        if user.nil?
          head :unauthorized
          return
        end

        Current.user = user
      end

      def current_user
        Current.user
      end

      def bearer_token
        header = request.authorization.to_s.strip
        return if header.blank?

        header.delete_prefix("Bearer ").strip.presence
      end

      def clear_current_user
        Current.reset
      end
    end
  end
end
