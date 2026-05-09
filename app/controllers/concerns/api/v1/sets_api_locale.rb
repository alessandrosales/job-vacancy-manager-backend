# frozen_string_literal: true

module Api
  module V1
    module SetsApiLocale
      extend ActiveSupport::Concern

      included do
        before_action :set_api_locale
      end

      # Guest controllers (JWT absent): stays nil → Accept-Language is used by ApiLocale.
      def authenticated_user_for_locale
        nil
      end

      private

      def set_api_locale
        preferred =
          authenticated_user_for_locale&.preferred_language
        header = request.get_header("HTTP_ACCEPT_LANGUAGE")

        I18n.locale =
          ApiLocale.from_storage_or_header(
            preferred_language_code: preferred,
            accept_language: header
          )
      end
    end
  end
end
