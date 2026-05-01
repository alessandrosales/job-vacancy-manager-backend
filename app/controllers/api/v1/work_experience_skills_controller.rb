# frozen_string_literal: true

module Api
  module V1
    class WorkExperienceSkillsController < AuthenticatedController
      before_action :set_work_experience

      def update
        ids = normalize_id_list(skill_sync_params[:skill_ids])
        unless @work_experience.sync_skill_links!(current_user, ids)
          render json: {
            errors: { skill_ids: [ "must reference only skills owned by the current user" ] }
          }, status: :unprocessable_entity
          return
        end

        render json: ordered_skills_payload(ids)
      end

      private

      def set_work_experience
        @work_experience = current_user.work_experiences.find_by(id: params[:work_experience_id])
        head(:not_found) && return if @work_experience.blank?
      end

      def skill_sync_params
        params.require(:work_experience_skill).permit(skill_ids: [])
      end

      def normalize_id_list(raw)
        Array(raw).map(&:presence).compact.uniq
      end

      def ordered_skills_payload(skill_ids)
        return [] if skill_ids.empty?

        by_id = @work_experience.skills.where(id: skill_ids).index_by(&:id)
        skill_ids.filter_map { |sid| by_id[sid]&.as_api_json }
      end
    end
  end
end
