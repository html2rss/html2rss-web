# frozen_string_literal: true

require 'time'

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
              return if env_health_check_token?(request)

              account = Auth.authenticate(request)
              return if account && account[:username] == 'health-check'

              raise Html2rss::Web::UnauthorizedError, 'Health check authentication required'
            end

            # @param request [Rack::Request]
            # @return [Boolean]
            def env_health_check_token?(request)
              configured_token = ENV.fetch('HEALTH_CHECK_TOKEN', '').to_s
              provided_token = bearer_token(request)
              return false if configured_token.empty? || provided_token.nil?
              return false unless configured_token.bytesize == provided_token.bytesize

              Rack::Utils.secure_compare(provided_token, configured_token)
            end

            # @param request [Rack::Request]
            # @return [String, nil]
            def bearer_token(request)
              auth_header = request.env['HTTP_AUTHORIZATION']
              return unless auth_header&.start_with?('Bearer ')

              token = auth_header.delete_prefix('Bearer ')
              return if token.empty?

              token
            end

            # @return [void]
            def verify_configuration!
              LocalConfig.yaml
            rescue StandardError
              raise Html2rss::Web::InternalServerError, Contract::MESSAGES[:health_check_failed]
            end
          end
        end
      end
    end
  end
end
