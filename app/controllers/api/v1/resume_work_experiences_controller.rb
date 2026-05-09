# frozen_string_literal: true

module Api
  module V1
    class ResumeWorkExperiencesController < AuthenticatedController
      include ResumeScoped

      def update
        ids = normalize_id_list(sync_params[:work_experience_ids])
        unless @resume.sync_work_experience_links!(current_user, ids)
          render json: {
            errors: {
              work_experience_ids: [ I18n.t("api.errors.join_tables.work_experience_ids_must_be_owned") ]
            }
          }, status: :unprocessable_entity
          return
        end

        render json: ordered_payload(@resume.work_experiences, ids)
      end

      private

      def sync_params
        params.require(:resume_work_experience).permit(work_experience_ids: [])
      end

      def normalize_id_list(raw)
        Array(raw).map(&:presence).compact.uniq
      end

      def ordered_payload(relation, ids)
        return [] if ids.empty?

        by_id = relation.where(id: ids).index_by(&:id)
        ids.filter_map { |rid| by_id[rid]&.as_api_json }
      end
    end
  end
end
