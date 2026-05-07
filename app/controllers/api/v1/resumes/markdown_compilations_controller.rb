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
              ai_token: [ "Add your OpenAI API key in My data, or configure OPENAI_API_KEY on the server." ]
            }
          }, status: :unprocessable_entity
        rescue Resume::MarkdownCompiler::Error => e
          render json: { errors: { base: [ e.message ] } }, status: :unprocessable_entity
        end
      end
    end
  end
end
