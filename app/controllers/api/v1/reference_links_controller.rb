# frozen_string_literal: true

module Api
  module V1
    class ReferenceLinksController < AuthenticatedController
      before_action :set_reference_link, only: %i[ show update destroy ]

      def index
        render json: current_user.reference_links.order(created_at: :desc).map(&:as_api_json)
      end

      def show
        render json: @reference_link.as_api_json
      end

      def create
        reference_link = current_user.reference_links.build(reference_link_params)
        if reference_link.save
          render json: reference_link.as_api_json, status: :created
        else
          render json: { errors: reference_link.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @reference_link.update(reference_link_params)
          render json: @reference_link.as_api_json
        else
          render json: { errors: @reference_link.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @reference_link.destroy!
        head :no_content
      end

      private

      def set_reference_link
        @reference_link = current_user.reference_links.find_by(id: params[:id])
        head(:not_found) && return if @reference_link.blank?
      end

      def reference_link_params
        params.require(:reference_link).permit(:title, :url)
      end
    end
  end
end
