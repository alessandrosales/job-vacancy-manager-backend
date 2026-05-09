# frozen_string_literal: true

module Api
  module V1
    module Resumes
      class MarkdownCompilationsController < AuthenticatedController
        include ResumeScoped

        def create
          resume = Resume::MarkdownCompiler.call(resume: @resume)
          render json: resume.as_api_json, status: :ok
        rescue User::RubyLlmContext::MissingApiKeyError
          render json: {
            errors: {
              ai_token: [ I18n.t("api.errors.resume.ai_token_missing") ]
            }
          }, status: :unprocessable_entity
        rescue Resume::MarkdownCompiler::Error => e
          render json: { errors: { base: [ e.translate ] } }, status: :unprocessable_entity
        end
      end
    end
  end
end
