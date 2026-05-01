# frozen_string_literal: true

module Api
  module V1
    class RolesController < AuthenticatedController
      before_action :set_role, only: %i[ show update destroy ]

      def index
        render json: current_user.roles.order(created_at: :desc).map(&:as_api_json)
      end

      def show
        render json: @role.as_api_json
      end

      def create
        role = current_user.roles.build(role_params)
        if role.save
          render json: role.as_api_json, status: :created
        else
          render json: { errors: role.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @role.update(role_params)
          render json: @role.as_api_json
        else
          render json: { errors: @role.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @role.destroy!
        head :no_content
      end

      private

      def set_role
        @role = current_user.roles.find_by(id: params[:id])
        head(:not_found) && return if @role.blank?
      end

      def role_params
        params.require(:role).permit(:name, :description, :interest_level)
      end
    end
  end
end
