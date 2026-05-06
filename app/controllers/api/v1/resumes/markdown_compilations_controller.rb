# frozen_string_literal: true

module Api
  module V1
    module Resumes
      class MarkdownCompilationsController < AuthenticatedController
        include ResumeScoped

        def create
          resume = Resume::MarkdownCompiler.call(resume: @resume)
          render json: resume.as_api_json, status: :ok
        rescue Resume::MarkdownCompiler::Error => e
          render json: { errors: { base: [ e.message ] } }, status: :unprocessable_entity
        end
      end
    end
  end
end
