# frozen_string_literal: true

module Api
  module V1
    module Resumes
      class PdfImportsController < AuthenticatedController
        def create
          uploaded = params[:file]
          unless uploaded.respond_to?(:tempfile) && uploaded.tempfile
            render json: { errors: { file: [ I18n.t("api.errors.resume.pdf.multipart_required") ] } }, status: :unprocessable_entity
            return
          end

          unless pdf?(uploaded)
            render json: { errors: { file: [ I18n.t("api.errors.resume.pdf.must_be_pdf") ] } }, status: :unprocessable_entity
            return
          end

          role_id = params[:role_id].to_s.presence
          if role_id.blank?
            render json: { errors: { role_id: [ I18n.t("api.errors.resume.pdf.role_id_blank") ] } }, status: :unprocessable_entity
            return
          end

          resume = Resume::PdfImporter.call(
            user: current_user,
            role_id: role_id,
            pdf_io: uploaded.tempfile,
            preferred_language: params[:preferred_language]
          )
          render json: resume.as_api_json, status: :created
        rescue User::RubyLlmContext::MissingApiKeyError
          render json: {
            errors: {
              ai_token: [ I18n.t("api.errors.resume.ai_token_missing") ]
            }
          }, status: :unprocessable_entity
        rescue Resume::PdfImporter::Error => e
          render json: { errors: { base: [ e.translate ] } }, status: :unprocessable_entity
        rescue ActiveRecord::RecordNotFound
          render json: { errors: { role_id: [ I18n.t("api.errors.resume.pdf.role_invalid") ] } }, status: :not_found
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: e.record.errors.as_json }, status: :unprocessable_entity
        end

        private

        def pdf?(uploaded)
          ct = uploaded.content_type.to_s
          return true if ct == "application/pdf"

          uploaded.original_filename.to_s.downcase.end_with?(".pdf")
        end
      end
    end
  end
end
