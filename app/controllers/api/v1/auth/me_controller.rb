# frozen_string_literal: true

module Api
  module V1
    module Auth
      class MeController < AuthenticatedController
        def show
          render json: current_user.as_api_json, status: :ok
        end
      end
    end
  end
end
