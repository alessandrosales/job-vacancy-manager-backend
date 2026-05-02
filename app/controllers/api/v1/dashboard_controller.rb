# frozen_string_literal: true

module Api
  module V1
    class DashboardController < AuthenticatedController
      def show
        render json: ::DashboardSummary.new(current_user).call
      end
    end
  end
end
