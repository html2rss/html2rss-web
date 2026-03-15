# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        module Contract
          CODES = {
            unauthorized: Html2rss::Web::UnauthorizedError::CODE,
            forbidden: Html2rss::Web::ForbiddenError::CODE,
            internal_server_error: Html2rss::Web::InternalServerError::CODE
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
