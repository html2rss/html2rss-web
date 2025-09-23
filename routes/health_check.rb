# frozen_string_literal: true

require_relative '../app/health_check'
require_relative '../app/auth'

module Html2rss
  module Web
    module HealthCheckRoutes
      module_function

      def handle_health_check_routes(router)
        health_check_account = HealthCheck.find_health_check_account
        account = Auth.authenticate(router)

        if account && health_check_account && account[:token] == health_check_account[:token]
          router.response['Content-Type'] = 'text/plain'
          HealthCheck.run
        else
          router.response.status = 401
          router.response['WWW-Authenticate'] = 'Bearer realm="Health Check"'
          router.response['Content-Type'] = 'application/xml'
          require_relative '../app/xml_builder'
          XmlBuilder.build_error_feed(message: 'Unauthorized', title: 'Health Check Unauthorized')
        end
      end
    end
  end
end
