# frozen_string_literal: true

require_relative '../../exceptions'

module Html2rss
  module Web
    module Api
      module V1
        module Contract
          CODES = {
            unauthorized: UnauthorizedError::CODE,
            forbidden: ForbiddenError::CODE,
            internal_server_error: InternalServerError::CODE
          }.freeze

          MESSAGES = {
            auto_source_disabled: 'Auto source feature is disabled',
            health_check_failed: 'Health check failed'
          }.freeze
        end
      end
    end
  end
end
