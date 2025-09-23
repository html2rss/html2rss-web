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

      EnvironmentValidator.validate_environment!
      EnvironmentValidator.validate_production_security!

      RodaConfig.configure(self)

      plugin :hash_branches

      Dir['routes/*.rb'].each { |f| require_relative f }

      @show_backtrace = development? && !ENV['CI']

      AppRoutes.load_routes(self)

      route do |r|
        r.public
        r.hash_branches('')

        r.root do
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
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <style>
              body { font-family: system-ui, sans-serif; max-width: 800px; margin: 0 auto; padding: 2rem; line-height: 1.6; }
              h1 { color: #111827; }
              code { background: #f3f4f6; padding: 0.2rem 0.4rem; border-radius: 0.25rem; }
            </style>
          </head>
          <body>
            <h1>html2rss-web</h1>
            <p>Convert websites to RSS feeds</p>
            <p>API available at <code>/api/</code></p>
          </body>
          </html>
        HTML
      end
    end
  end
end
