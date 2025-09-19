# frozen_string_literal: true

require_relative 'health_check'
require_relative 'auth'
require_relative 'xml_builder'

module Html2rss
  module Web
    ##
    # Health check routes for the html2rss-web application
    module HealthCheckRoutes
      module_function

      ##
      # Handle the health_check.txt hash branch routing
      # @param router [Roda::Roda] The Roda router instance
      def handle_health_check_routes(router)
        handle_health_check(router)
      end

      private

      ##
      # Handle health check request with authentication
      # @param router [Roda::Roda] The Roda router instance
      def handle_health_check(router)
        token_data = Auth.authenticate(router)
        health_check_account = HealthCheck.find_health_check_account

        if token_data && health_check_account && token_data[:token] == health_check_account[:token]
          router.response['Content-Type'] = 'text/plain'
          HealthCheck.run
        else
          health_check_unauthorized(router)
        end
      end

      ##
      # Return unauthorized response for health check
      # @param router [Roda::Roda] The Roda router instance
      def health_check_unauthorized(router)
        router.response.status = 401
        router.response['Content-Type'] = 'application/xml'
        router.response['WWW-Authenticate'] = 'Bearer realm="Health Check"'
        XmlBuilder.build_error_feed(message: 'Unauthorized', title: 'Health Check Unauthorized')
      end
    end
  end
end
