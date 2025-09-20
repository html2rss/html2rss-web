# frozen_string_literal: true

require_relative '../app/health_check'
require_relative '../app/base_route_handler'

module Html2rss
  module Web
    ##
    # Health check routes for the html2rss-web application
    # Now uses BaseRouteHandler to eliminate repetitive patterns
    module HealthCheckRoutes
      module_function

      ##
      # Handle the health_check.txt hash branch routing
      # @param router [Roda::Roda] The Roda router instance
      def handle_health_check_routes(router)
        context = BaseRouteHandler.create_context(router)
        handle_health_check(context)
      end

      private

      ##
      # Handle health check request with authentication
      # @param context [RequestContext] The request context
      def handle_health_check(context)
        health_check_account = HealthCheck.find_health_check_account

        if context.authenticated && health_check_account && context.account[:token] == health_check_account[:token]
          context.response_context.response['Content-Type'] = 'text/plain'
          HealthCheck.run
        else
          health_check_unauthorized(context)
        end
      end

      ##
      # Return unauthorized response for health check
      # @param context [RequestContext] The request context
      def health_check_unauthorized(context)
        context.response_context.set_headers(401)
        context.response_context.response['WWW-Authenticate'] = 'Bearer realm="Health Check"'
        require_relative 'xml_builder'
        XmlBuilder.build_error_feed(message: 'Unauthorized', title: 'Health Check Unauthorized')
      end
    end
  end
end
