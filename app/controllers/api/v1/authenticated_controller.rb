# frozen_string_literal: true

module Api
  module V1
    class AuthenticatedController < BaseController
      include Authenticatable
      include Paginatable

      private

      def authenticated_user_for_locale
        Current.user
      end
    end
  end
end
