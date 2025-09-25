# frozen_string_literal: true

require_relative '../../auth'
require_relative '../../health_check'
require_relative '../../exceptions'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # RESTful API v1 for health check resource
        # Handles application health monitoring
        module Health
          module_function

          def show(request) # rubocop:disable Metrics/MethodLength
            health_check_account = HealthCheck.find_health_check_account
            account = Auth.authenticate(request)

            unless account && health_check_account && account[:token] == health_check_account[:token]
              raise UnauthorizedError, 'Health check authentication required'
            end

            health_result = HealthCheck.run

            raise InternalServerError, 'Health check failed' unless health_result == 'success'

            {
              success: true,
              data: {
                health: {
                  status: 'healthy',
                  timestamp: Time.now.iso8601,
                  version: '1.0.0',
                  environment: ENV['RACK_ENV'] || 'development',
                  checks: {}
                }
              }
            }
          end

          def ready(_request)
            # Simple readiness check - just verify the app can respond
            { success: true, data: { readiness: {
              status: 'ready',
              timestamp: Time.now.iso8601,
              version: '1.0.0'
            } } }
          end

          def live(_request)
            # Simple liveness check - just verify the app is running
            { success: true, data: { liveness: {
              status: 'alive',
              timestamp: Time.now.iso8601,
              uptime: Process.clock_gettime(Process::CLOCK_MONOTONIC)
            } } }
          end
        end
      end
    end
  end
end
