# frozen_string_literal: true

module Api
  module V1
    class CompaniesController < AuthenticatedController
      before_action :set_company, only: %i[show update destroy]

      def index
        render_paginated(current_user.companies.order(created_at: :desc))
      end

      def show
        render json: @company.as_api_json
      end

      def create
        company = current_user.companies.build(company_params)
        if company.save
          render json: company.as_api_json, status: :created
        else
          render json: { errors: company.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @company.update(company_params)
          render json: @company.as_api_json
        else
          render json: { errors: @company.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @company.destroy!
        head :no_content
      end

      private

      def set_company
        @company = current_user.companies.find_by(id: params[:id])
        head(:not_found) && return if @company.blank?
      end

      def company_params
        params.require(:company).permit(:name, :url, :description, :interest_level)
      end
    end
  end
end
