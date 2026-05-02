# frozen_string_literal: true

module Api
  module V1
    class OpportunityStatusesController < AuthenticatedController
      before_action :set_opportunity_status, only: %i[show update destroy]

      def index
        render_paginated(current_user.opportunity_statuses.order(position: :asc, created_at: :asc))
      end

      def show
        render json: @opportunity_status.as_api_json
      end

      def create
        status = current_user.opportunity_statuses.build(opportunity_status_params)
        if status.save
          render json: status.as_api_json, status: :created
        else
          render json: { errors: status.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @opportunity_status.update(opportunity_status_params)
          render json: @opportunity_status.as_api_json
        else
          render json: { errors: @opportunity_status.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        if @opportunity_status.destroy
          head :no_content
        else
          render json: { errors: @opportunity_status.errors.as_json }, status: :unprocessable_entity
        end
      end

      private

      def set_opportunity_status
        @opportunity_status = current_user.opportunity_statuses.find_by(id: params[:id])
        head(:not_found) && return if @opportunity_status.blank?
      end

      def opportunity_status_params
        params.require(:opportunity_status).permit(:label, :description, :variant, :position)
      end
    end
  end
end
