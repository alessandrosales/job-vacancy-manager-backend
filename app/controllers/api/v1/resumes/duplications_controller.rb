# frozen_string_literal: true

module Api
  module V1
    module Resumes
      class DuplicationsController < AuthenticatedController
        include ResumeScoped

        def create
          duplicated = @resume.duplicate_for_user!(user: current_user)
          render json: duplicated.as_api_json, status: :created
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: e.record.errors.as_json }, status: :unprocessable_entity
        end
      end
    end
  end
end
