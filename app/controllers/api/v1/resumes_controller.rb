# frozen_string_literal: true

module Api
  module V1
    class ResumesController < AuthenticatedController
      RESUME_JSON_INCLUDES = %i[
        resume_work_experiences
        resume_certifications
        resume_educations
        resume_skills
      ].freeze

      before_action :set_resume, only: %i[show update destroy]

      def index
        render_paginated(
          current_user.resumes.includes(RESUME_JSON_INCLUDES).order(created_at: :desc)
        )
      end

      def show
        render json: @resume.as_api_json
      end

      def create
        resume = current_user.resumes.build(resume_params)
        if resume.save
          render json: resume.as_api_json, status: :created
        else
          render json: { errors: resume.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @resume.update(resume_params)
          render json: @resume.as_api_json
        else
          render json: { errors: @resume.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @resume.destroy!
        head :no_content
      end

      private

      def set_resume
        @resume = current_user.resumes.includes(RESUME_JSON_INCLUDES).find_by(id: params[:id])
        head(:not_found) && return if @resume.blank?
      end

      def resume_params
        params.require(:resume).permit(:title, :description, :role_id, :preferred_language)
      end
    end
  end
end
