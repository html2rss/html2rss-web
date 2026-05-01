# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 500 error raised when shallow health checks cannot read configuration.
    class HealthCheckFailedError < InternalServerError
      DEFAULT_MESSAGE = 'Health check failed'
    end
  end
end
