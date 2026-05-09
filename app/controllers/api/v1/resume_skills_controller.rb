# frozen_string_literal: true

module Api
  module V1
    class ResumeSkillsController < AuthenticatedController
      include ResumeScoped

      def update
        ids = normalize_id_list(sync_params[:skill_ids])
        unless @resume.sync_skill_links!(current_user, ids)
          render json: {
            errors: { skill_ids: [ I18n.t("api.errors.join_tables.skill_ids_must_be_owned") ] }
          }, status: :unprocessable_entity
          return
        end

        render json: ordered_payload(@resume.skills, ids)
      end

      private

      def sync_params
        params.require(:resume_skill).permit(skill_ids: [])
      end

      def normalize_id_list(raw)
        Array(raw).map(&:presence).compact.uniq
      end

      def ordered_payload(relation, ids)
        return [] if ids.empty?

        by_id = relation.where(id: ids).index_by(&:id)
        ids.filter_map { |sid| by_id[sid]&.as_api_json }
      end
    end
  end
end
