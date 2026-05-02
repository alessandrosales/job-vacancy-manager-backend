# frozen_string_literal: true

# Adds opt-out pagination to API index actions.
#
#   render_paginated(current_user.opportunities.order(...))
#
# Default response is enveloped:
#   { "data" => [...], "meta" => { "current_page", "per_page", "total_pages", "total_count" } }
#
# Pass +?paginated=false+ (or +0+, +no+) to receive a bare array (legacy shape).
# +page+ defaults to 1 and clamps to >= 1; +per_page+ defaults to 25 and clamps to 1..100.
# Invalid integers are coerced to defaults instead of raising +400+.
module Api
  module V1
    module Paginatable
      extend ActiveSupport::Concern

      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100
      FALSY_VALUES = %w[false 0 no].freeze

      def render_paginated(scope, &serializer)
        records, meta = paginate(scope)
        serialize = serializer || ->(record) { record.as_api_json }
        body = records.map(&serialize)
        if meta
          render json: { data: body, meta: meta }
        else
          render json: body
        end
      end

      def paginate(scope)
        if pagination_enabled?
          page = current_page
          limit = per_page
          total_count = scope.count
          total_pages = total_count.zero? ? 0 : (total_count.to_f / limit).ceil
          records = scope.limit(limit).offset((page - 1) * limit).to_a
          meta = {
            current_page: page,
            per_page: limit,
            total_pages: total_pages,
            total_count: total_count
          }
          [ records, meta ]
        else
          [ scope.to_a, nil ]
        end
      end

      private

      def pagination_enabled?
        raw = params[:paginated]
        return true if raw.nil?
        !FALSY_VALUES.include?(raw.to_s.strip.downcase)
      end

      def current_page
        raw = params[:page].to_s.strip
        page = Integer(raw, 10) rescue 1
        page < 1 ? 1 : page
      end

      def per_page
        raw = params[:per_page].to_s.strip
        value = Integer(raw, 10) rescue DEFAULT_PER_PAGE
        return DEFAULT_PER_PAGE if value < 1
        value > MAX_PER_PAGE ? MAX_PER_PAGE : value
      end
    end
  end
end
