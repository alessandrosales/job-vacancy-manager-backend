# frozen_string_literal: true

module Api
  module V1
    class EducationsController < AuthenticatedController
      before_action :set_education, only: %i[show update destroy]

      def index
        render_paginated(current_user.educations.order(created_at: :desc))
      end

      def show
        render json: @education.as_api_json
      end

      def create
        education = current_user.educations.build(education_params)
        if education.save
          render json: education.as_api_json, status: :created
        else
          render json: { errors: education.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @education.update(education_params)
          render json: @education.as_api_json
        else
          render json: { errors: @education.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @education.destroy!
        head :no_content
      end

      private

      def set_education
        @education = current_user.educations.find_by(id: params[:id])
        head(:not_found) && return if @education.blank?
      end

      def education_params
        params.require(:education).permit(:institution_name, :degree, :field_of_study, :date_from, :date_to)
      end
    end
  end
end
