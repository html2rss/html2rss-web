# frozen_string_literal: true

require 'time'

require_relative '../../security/auth'
require_relative '../../errors/exceptions'
require_relative '../../config/local_config'
require_relative 'contract'
require_relative 'response'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Health endpoints for API v1.
        #
        # Keeps checks intentionally shallow (auth + config readability) so
        # probes stay fast and deterministic.
        module Health
          class << self
            # @param request [Rack::Request]
            # @return [Hash{Symbol=>Object}] authenticated health payload.
            def show(request)
              authorize_health_check!(request)
              verify_configuration!

              health_response
            end

            # @param _request [Rack::Request]
            # @return [Hash{Symbol=>Object}] readiness payload.
            def ready(_request)
              verify_configuration!
              health_response
            end

            # @param _request [Rack::Request]
            # @return [Hash{Symbol=>Object}] liveness payload.
            def live(_request)
              Response.success(data: { health: { status: 'alive', timestamp: Time.now.iso8601 } })
            end

            private

            # @return [Hash{Symbol=>Object}]
            def health_response
              Response.success(data: { health: health_payload })
            end

            # @return [Hash{Symbol=>Object}]
            # @option return [String] :status health status text.
            # @option return [String] :timestamp ISO8601 timestamp.
            # @option return [String] :environment rack environment.
            # @option return [Float] :uptime process uptime seconds.
            # @option return [Hash] :checks reserved health checks map.
            def health_payload
              {
                status: 'healthy',
                timestamp: Time.now.iso8601,
                environment: ENV.fetch('RACK_ENV', 'development'),
                uptime: Process.clock_gettime(Process::CLOCK_MONOTONIC),
                checks: {}
              }
            end

            # @param request [Rack::Request]
            # @return [void]
            def authorize_health_check!(request)
              account = Auth.authenticate(request)
              return if account && account[:username] == 'health-check'

              raise UnauthorizedError, 'Health check authentication required'
            end

            # @return [void]
            def verify_configuration!
              LocalConfig.yaml
            rescue StandardError
              raise InternalServerError, Contract::MESSAGES[:health_check_failed]
            end
          end
        end
      end
    end
  end
end
