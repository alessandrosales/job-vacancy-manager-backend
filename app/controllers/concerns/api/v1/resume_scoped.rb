# frozen_string_literal: true

module Api
  module V1
    module ResumeScoped
      extend ActiveSupport::Concern

      included do
        before_action :set_resume
      end

      private

      def set_resume
        @resume = current_user.resumes.find_by(id: params[:resume_id])
        head(:not_found) && return if @resume.blank?
      end
    end
  end
end
