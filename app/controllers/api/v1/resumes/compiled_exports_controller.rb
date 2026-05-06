# frozen_string_literal: true

module Api
  module V1
    module Resumes
      class CompiledExportsController < AuthenticatedController
        include ResumeScoped

        def show
          result = Resume::CompiledExport.render(resume: @resume, format: export_format)
          send_data(
            result.bytes,
            filename: result.filename,
            type: result.content_type,
            disposition: "attachment"
          )
        rescue Resume::CompiledExport::Error => e
          render json: { errors: { base: [ e.message ] } }, status: :unprocessable_entity
        end

        private

        def export_format
          params[:format].to_s.downcase.strip
        end
      end
    end
  end
end
