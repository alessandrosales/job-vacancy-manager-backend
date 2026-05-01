# frozen_string_literal: true

module Api
  module V1
    class AuthenticatedController < BaseController
      include Authenticatable
    end
  end
end
