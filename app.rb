# frozen_string_literal: true

require 'roda'
require 'rack/cache'
require 'json'

require 'html2rss'
require_relative 'app/environment_validator'
require_relative 'app/roda_config'
require_relative 'app/auth'
require_relative 'app/auto_source'
require_relative 'app/feeds'
require_relative 'app/health_check'
require_relative 'app/response_context'
require_relative 'app/request_context'
require_relative 'app/base_route_handler'
require_relative 'app/xml_builder'
require_relative 'app/security_logger'

module Html2rss
  module Web
    ##
    # This app uses html2rss and serves the feeds via HTTP.
    #
    # It is built with [Roda](https://roda.jeremyevans.net/).
    class App < Roda
      CONTENT_TYPE_RSS = 'application/xml'

      def self.development? = ENV['RACK_ENV'] == 'development'
      def development? = self.class.development?

      # Validate environment on class load
      EnvironmentValidator.validate_environment!
      EnvironmentValidator.validate_production_security!

      # Configure Roda app
      RodaConfig.configure(self)

      # Load hash_branches plugin for Large Applications
      plugin :hash_branches

      # Load all route files
      Dir['routes/*.rb'].each { |f| require_relative f }

      @show_backtrace = development? && !ENV['CI']

      # Load all routes
      AppRoutes.load_routes(self)

      route do |r|
        r.public
        r.hash_branches('')

        r.root do
          # Handle root path
          index_path = 'public/frontend/index.html'
          response['Content-Type'] = 'text/html'

          if File.exist?(index_path)
            File.read(index_path)
          else
            fallback_html
          end
        end
      end

      def fallback_html
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>html2rss-web</title>
            <link rel="stylesheet" href="/water.css">
          </head>
          <body>
            <h1>html2rss-web</h1>
            <p>Convert websites to RSS feeds</p>
            <p>API available at <code>/api/</code></p>
          </body>
          </html>
        HTML
      end

      # Load all helper files
      Dir['helpers/*.rb'].each { |f| require_relative f }
    end
  end
end
