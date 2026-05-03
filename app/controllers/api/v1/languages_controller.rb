# frozen_string_literal: true

module Api
  module V1
    class LanguagesController < AuthenticatedController
      before_action :set_language, only: %i[ show update destroy ]

      def index
        render_paginated(current_user.languages.order(created_at: :desc))
      end

      def show
        render json: @language.as_api_json
      end

      def create
        language = current_user.languages.build(language_params)
        if language.save
          render json: language.as_api_json, status: :created
        else
          render json: { errors: language.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @language.update(language_params)
          render json: @language.as_api_json
        else
          render json: { errors: @language.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @language.destroy!
        head :no_content
      end

      private

      def set_language
        @language = current_user.languages.find_by(id: params[:id])
        head(:not_found) && return if @language.blank?
      end

      def language_params
        params.require(:language).permit(:name, :level)
      end
    end
  end
end
