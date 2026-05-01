# frozen_string_literal: true

require Rails.root.join("lib/json_empty_body_middleware")

Rails.application.config.middleware.insert_before Rack::Runtime, JsonEmptyBodyMiddleware
