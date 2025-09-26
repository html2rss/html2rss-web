# frozen_string_literal: true

require 'time'

require_relative '../../auth'
require_relative '../../exceptions'
require_relative '../../local_config'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # RESTful API v1 for health check resource
        # Handles application health monitoring
        module Health
          module_function

          def show(request)
            authorize_health_check!(request)
            verify_configuration!

            health_response
          end

          def health_response
            {
              success: true,
              data: { health: health_payload }
            }
          end

          def health_payload
            {
              status: 'healthy',
              timestamp: Time.now.iso8601,
              environment: ENV.fetch('RACK_ENV', 'development'),
              uptime: Process.clock_gettime(Process::CLOCK_MONOTONIC),
              checks: {}
            }
          end

          def authorize_health_check!(request)
            account = Auth.authenticate(request)
            return if account && account[:username] == 'health-check'

            raise UnauthorizedError, 'Health check authentication required'
          end

          def verify_configuration!
            LocalConfig.yaml
          rescue StandardError => error
            raise InternalServerError, "Health check failed: #{error.message}"
          end
        end
      end
    end
  end
end
