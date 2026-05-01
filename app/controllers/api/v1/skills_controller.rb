# frozen_string_literal: true

module Api
  module V1
    class SkillsController < AuthenticatedController
      before_action :set_skill, only: %i[ show update destroy ]

      def index
        render json: current_user.skills.order(created_at: :desc).map(&:as_api_json)
      end

      def show
        render json: @skill.as_api_json
      end

      def create
        skill = current_user.skills.build(skill_params)
        if skill.save
          render json: skill.as_api_json, status: :created
        else
          render json: { errors: skill.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @skill.update(skill_params)
          render json: @skill.as_api_json
        else
          render json: { errors: @skill.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @skill.destroy!
        head :no_content
      end

      private

      def set_skill
        @skill = current_user.skills.find_by(id: params[:id])
        head(:not_found) && return if @skill.blank?
      end

      def skill_params
        params.require(:skill).permit(:name, :description)
      end
    end
  end
end
