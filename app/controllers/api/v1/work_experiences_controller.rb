# frozen_string_literal: true

module Api
  module V1
    class WorkExperiencesController < AuthenticatedController
      before_action :set_work_experience, only: %i[ show update destroy ]

      def index
        render_paginated(current_user.work_experiences.order(created_at: :desc))
      end

      def show
        render json: @work_experience.as_api_json
      end

      def create
        work_experience = current_user.work_experiences.build(work_experience_params)
        if work_experience.save
          render json: work_experience.as_api_json, status: :created
        else
          render json: { errors: work_experience.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @work_experience.update(work_experience_params)
          render json: @work_experience.as_api_json
        else
          render json: { errors: @work_experience.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @work_experience.destroy!
        head :no_content
      end

      private

      def set_work_experience
        @work_experience = current_user.work_experiences.find_by(id: params[:id])
        head(:not_found) && return if @work_experience.blank?
      end

      def work_experience_params
        params.require(:work_experience).permit(:title, :description, :company_name, :is_remote, :date_from, :date_to)
      end
    end
  end
end
