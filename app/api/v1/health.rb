# frozen_string_literal: true

require_relative '../../auth'
require_relative '../../health_check'
require_relative '../../exceptions'
require_relative '../../../helpers/api_response_helpers'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # RESTful API v1 for health check resource
        # Handles application health monitoring
        module Health
          module_function

          ##
          # Get application health status
          # GET /api/v1/health
          # @param request [Roda::Request] request object
          # @return [Hash] JSON response with health status
          def show(request)
            health_check_account = HealthCheck.find_health_check_account
            account = Auth.authenticate(request)

            unless account && health_check_account && account[:token] == health_check_account[:token]
              raise UnauthorizedError,
                    'Health check authentication required'
            end

            health_result = HealthCheck.run

            raise InternalServerError, 'Health check failed' unless health_result == 'success'

            ApiResponseHelpers.success_response({
                                                  health: {
                                                    status: 'healthy',
                                                    timestamp: Time.now.iso8601,
                                                    version: '1.0.0',
                                                    environment: ENV['RACK_ENV'] || 'development',
                                                    checks: {}
                                                  }
                                                })
          end

          ##
          # Get application readiness status
          # GET /api/v1/health/ready
          # @param request [Roda::Request] request object
          # @return [Hash] JSON response with readiness status
          def ready(request)
            # Simple readiness check - just verify the app can respond
            ApiResponseHelpers.success_response({
                                                  readiness: {
                                                    status: 'ready',
                                                    timestamp: Time.now.iso8601,
                                                    version: '1.0.0'
                                                  }
                                                })
          end

          ##
          # Get application liveness status
          # GET /api/v1/health/live
          # @param request [Roda::Request] request object
          # @return [Hash] JSON response with liveness status
          def live(request)
            # Simple liveness check - just verify the app is running
            ApiResponseHelpers.success_response({
                                                  liveness: {
                                                    status: 'alive',
                                                    timestamp: Time.now.iso8601,
                                                    uptime: Process.clock_gettime(Process::CLOCK_MONOTONIC)
                                                  }
                                                })
          end
        end
      end
    end
  end
end
