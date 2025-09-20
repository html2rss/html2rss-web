# frozen_string_literal: true

require 'roda'
require 'rack/cache'
require 'json'

require 'html2rss'
require_relative 'app/environment_validator'
require_relative 'app/roda_config'
require_relative 'app/app_routes'
require_relative 'app/auth'
require_relative 'app/auto_source'
require_relative 'app/feeds'
require_relative 'app/health_check'
require_relative 'app/api_routes'
require_relative 'app/response_helpers'
require_relative 'app/static_file_helpers'
require_relative 'app/xml_builder'
require_relative 'app/auto_source_routes'
require_relative 'app/health_check_routes'
require_relative 'app/security_logger'

module Html2rss
  module Web
    ##
    # This app uses html2rss and serves the feeds via HTTP.
    #
    # It is built with [Roda](https://roda.jeremyevans.net/).
    class App < Roda
      include ApiRoutes
      include ResponseHelpers
      include StaticFileHelpers
      include AutoSourceRoutes
      include HealthCheckRoutes

      CONTENT_TYPE_RSS = 'application/xml'

      def self.development? = ENV['RACK_ENV'] == 'development'
      def development? = self.class.development?

      # Validate environment on class load
      EnvironmentValidator.validate_environment!
      EnvironmentValidator.validate_production_security!

      # Configure Roda app
      RodaConfig.configure(self)

      @show_backtrace = development? && !ENV['CI']

      # Define all routes
      AppRoutes.define_routes(self)
    end
  end
end
