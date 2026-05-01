module Api
  module V1
    class BaseController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :invalid_json_body

      private

      def record_not_found
        head :not_found
      end

      def invalid_json_body(_exception)
        render json: {
          errors: {
            base: [
              "Invalid JSON body. Send Content-Type: application/json with well-formed JSON " \
              "(e.g. {\"auth\":{\"email\":\"you@example.com\"}} for recover password)."
            ]
          }
        }, status: :bad_request
      end
    end
  end
end
