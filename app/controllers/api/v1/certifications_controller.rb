# frozen_string_literal: true

module Api
  module V1
    class CertificationsController < AuthenticatedController
      before_action :set_certification, only: %i[show update destroy]

      def index
        render json: current_user.certifications.order(created_at: :desc).map(&:as_api_json)
      end

      def show
        render json: @certification.as_api_json
      end

      def create
        certification = current_user.certifications.build(certification_params)
        if certification.save
          render json: certification.as_api_json, status: :created
        else
          render json: { errors: certification.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @certification.update(certification_params)
          render json: @certification.as_api_json
        else
          render json: { errors: @certification.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @certification.destroy!
        head :no_content
      end

      private

      def set_certification
        @certification = current_user.certifications.find_by(id: params[:id])
        head(:not_found) && return if @certification.blank?
      end

      def certification_params
        params.require(:certification).permit(:name, :date_from, :date_to)
      end
    end
  end
end
