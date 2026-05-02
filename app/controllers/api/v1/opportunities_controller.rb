# frozen_string_literal: true

module Api
  module V1
    class OpportunitiesController < AuthenticatedController
      before_action :set_opportunity, only: %i[show update destroy]

      def index
        render_paginated(current_user.opportunities.order(created_at: :desc))
      end

      def show
        render json: @opportunity.as_api_json
      end

      def create
        opportunity = current_user.opportunities.build(opportunity_params)
        if opportunity.save
          render json: opportunity.as_api_json, status: :created
        else
          render json: { errors: opportunity.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @opportunity.update(opportunity_params)
          render json: @opportunity.as_api_json
        else
          render json: { errors: @opportunity.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @opportunity.destroy!
        head :no_content
      end

      private

      def set_opportunity
        @opportunity = current_user.opportunities.find_by(id: params[:id])
        head(:not_found) && return if @opportunity.blank?
      end

      def opportunity_params
        params.require(:opportunity).permit(
          :company_id,
          :role_id,
          :status_id,
          :description,
          :url,
          :interest_level,
          :hourly_rate,
          :annual_salary
        )
      end
    end
  end
end
