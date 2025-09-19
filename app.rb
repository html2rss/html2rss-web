# frozen_string_literal: true

require 'roda'
require 'rack/cache'
require 'json'

require 'html2rss'
require_relative 'app/ssrf_filter_strategy'
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

      # Validate required environment variables on startup
      def self.validate_environment!
        return if ENV['HTML2RSS_SECRET_KEY']

        if development? || ENV['RACK_ENV'] == 'test'
          set_development_key
        else
          show_production_error
        end
      end

      def self.set_development_key
        ENV['HTML2RSS_SECRET_KEY'] = 'development-default-key-not-for-production'
        puts '⚠️  WARNING: Using default secret key for development/testing only!'
        puts '   Set HTML2RSS_SECRET_KEY environment variable for production use.'
      end

      def self.show_production_error
        puts production_error_message
        exit 1
      end

      def self.production_error_message
        <<~ERROR
          ❌ ERROR: HTML2RSS_SECRET_KEY environment variable is not set!

          This application is designed to be used via Docker Compose only.
          Please read the project's README.md for setup instructions.

          To generate a secure secret key and start the application:
            1. Generate a secret key: openssl rand -hex 32
            2. Edit docker-compose.yml and replace 'your-generated-secret-key-here' with your key
            3. Start with: docker-compose up

          For more information, see: https://github.com/html2rss/html2rss-web#configuration
        ERROR
      end

      def development? = self.class.development?

      # Validate environment on class load
      validate_environment!

      Html2rss::RequestService.register_strategy(:ssrf_filter, SsrfFilterStrategy)
      Html2rss::RequestService.default_strategy_name = :ssrf_filter
      Html2rss::RequestService.unregister_strategy(:faraday)

      opts[:check_dynamic_arity] = false
      opts[:check_arity] = :warn

      use Rack::Cache,
          metastore: 'file:./tmp/rack-cache-meta',
          entitystore: 'file:./tmp/rack-cache-body',
          verbose: false

      plugin :content_security_policy do |csp|
        csp.default_src :none
        csp.style_src :self, "'unsafe-inline'" # Allow inline styles for Starlight
        csp.script_src :self, "'unsafe-inline'" # Allow inline scripts for progressive enhancement
        csp.connect_src :self
        csp.img_src :self, 'data:', 'blob:'
        csp.font_src :self, 'data:'
        csp.form_action :self
        csp.base_uri :none
        csp.frame_ancestors :none # More restrictive than :self
        csp.frame_src :none # More restrictive than :self
        csp.object_src :none # Prevent object/embed/applet
        csp.media_src :none # Prevent media sources
        csp.manifest_src :none # Prevent manifest
        csp.worker_src :none # Prevent workers
        csp.child_src :none # Prevent child contexts
        csp.block_all_mixed_content
        csp.upgrade_insecure_requests # Upgrade HTTP to HTTPS
      end

      plugin :default_headers,
             'Content-Type' => 'text/html',
             'X-Content-Type-Options' => 'nosniff',
             'X-XSS-Protection' => '1; mode=block',
             'X-Frame-Options' => 'DENY',
             'X-Permitted-Cross-Domain-Policies' => 'none',
             'Referrer-Policy' => 'strict-origin-when-cross-origin',
             'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()',
             'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains; preload',
             'Cross-Origin-Embedder-Policy' => 'require-corp',
             'Cross-Origin-Opener-Policy' => 'same-origin',
             'Cross-Origin-Resource-Policy' => 'same-origin'

      plugin :exception_page
      plugin :error_handler do |error|
        next exception_page(error) if development?

        response.status = 500
        response['Content-Type'] = CONTENT_TYPE_RSS
        XmlBuilder.build_error_feed(message: error.message)
      end

      plugin :public
      plugin :hash_branches

      @show_backtrace = !ENV['CI'].to_s.empty? || development?

      # API routes
      hash_branch 'api' do |r|
        response['Content-Type'] = 'application/json'

        r.on 'feeds.json' do
          response['Cache-Control'] = 'public, max-age=300'
          JSON.generate(Feeds.list_feeds)
        end

        r.on 'strategies.json' do
          response['Cache-Control'] = 'public, max-age=3600'
          JSON.generate(ApiRoutes.list_available_strategies)
        end

        r.on String do |feed_name|
          ApiRoutes.handle_feed_generation(r, feed_name)
        end
      end

      # Stable feed routes (new)
      hash_branch 'feeds' do |r|
        r.on String do |feed_id|
          AutoSourceRoutes.handle_stable_feed(r, feed_id)
        end
      end

      # Auto source routes
      hash_branch 'auto_source' do |r|
        handle_auto_source_routes(r)
      end

      # Health check route
      hash_branch 'health_check.txt' do |r|
        handle_health_check_routes(r)
      end

      route do |r|
        r.public
        r.hash_branches
        handle_static_files(r)
      end
    end
  end
end
