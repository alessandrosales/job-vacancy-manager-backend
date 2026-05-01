# frozen_string_literal: true

module Api
  module V1
    class ResumeEducationsController < AuthenticatedController
      include ResumeScoped

      def update
        ids = normalize_id_list(sync_params[:education_ids])
        unless @resume.sync_education_links!(current_user, ids)
          render json: {
            errors: {
              education_ids: [ "must reference only educations owned by the current user" ]
            }
          }, status: :unprocessable_entity
          return
        end

        render json: ordered_payload(@resume.educations, ids)
      end

      private

      def sync_params
        params.require(:resume_education).permit(education_ids: [])
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
