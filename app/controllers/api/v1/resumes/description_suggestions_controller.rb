# frozen_string_literal: true

module Api
  module V1
    module Resumes
      class DescriptionSuggestionsController < AuthenticatedController
        def create
          attrs = suggestion_params
          if attrs[:title].to_s.strip.blank?
            render json: { errors: { title: [ "can't be blank" ] } }, status: :unprocessable_entity
            return
          end

          text = Resume::DescriptionGenerator.call(**attrs)
          render json: { description: text }, status: :ok
        rescue Resume::DescriptionGenerator::Error => e
          render json: { errors: { base: [ e.message ] } }, status: :unprocessable_entity
        end

        private

        def suggestion_params
          p = params.permit(
            :title,
            :role_name,
            :previous_description,
            :preferred_language,
            work_experience_summaries: [],
            certification_names: [],
            education_summaries: [],
            skill_names: []
          ).to_h.symbolize_keys

          {
            title: p[:title].to_s,
            role_name: p[:role_name].presence,
            previous_description: p[:previous_description].to_s,
            preferred_language: Resume.normalize_preferred_language(p[:preferred_language]),
            work_experience_summaries: Array(p[:work_experience_summaries]),
            certification_names: Array(p[:certification_names]),
            education_summaries: Array(p[:education_summaries]),
            skill_names: Array(p[:skill_names])
          }
        end
      end
    end
  end
end
