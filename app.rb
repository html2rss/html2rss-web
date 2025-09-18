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
        csp.style_src :self
        csp.script_src :self
        csp.connect_src :self
        csp.img_src :self
        csp.font_src :self, 'data:'
        csp.form_action :self
        csp.base_uri :none
        csp.frame_ancestors :self
        csp.frame_src :self
        csp.block_all_mixed_content
      end

      plugin :default_headers,
             'Content-Type' => 'text/html',
             'X-Content-Type-Options' => 'nosniff',
             'X-XSS-Protection' => '1; mode=block',
             'X-Frame-Options' => 'DENY',
             'X-Permitted-Cross-Domain-Policies' => 'none',
             'Referrer-Policy' => 'strict-origin-when-cross-origin',
             'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()'

      plugin :exception_page
      plugin :error_handler do |error|
        next exception_page(error) if ENV['RACK_ENV'] == 'development'

        response.status = 500
        'Internal Server Error'
      end

      plugin :public
      plugin :hash_branches

      @show_backtrace = !ENV['CI'].to_s.empty? || (ENV['RACK_ENV'] == 'development')

      # API routes
      hash_branch 'api' do |r|
        r.on 'feeds.json' do
          response['Content-Type'] = 'application/json'
          response['Cache-Control'] = 'public, max-age=300'
          JSON.generate(Feeds.list_feeds)
        end

        r.on 'strategies.json' do
          response['Content-Type'] = 'application/json'
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
          handle_stable_feed(r, feed_id)
        end
      end

      # Auto source routes
      hash_branch 'auto_source' do |r|
        return auto_source_disabled_response unless AutoSource.enabled?

        # New stable feed creation and management
        r.on 'create' do
          handle_create_feed(r)
        end

        r.on 'feeds' do
          handle_list_feeds(r)
        end

        # Legacy encoded URL route (for backward compatibility)
        r.on String do |encoded_url|
          handle_legacy_auto_source_feed(r, encoded_url)
        end
      end

      # Health check route
      hash_branch 'health_check.txt' do |r|
        handle_health_check(r)
      end

      route do |r|
        r.public
        r.hash_branches
        handle_static_files(r)
      end

      private

      # Auto source route helpers
      def auto_source_disabled_response
        response.status = 400
        'The auto source feature is disabled.'
      end

      def handle_stable_feed(router, feed_id)
        url = router.params['url']
        feed_token = router.params['token']

        return bad_request_response('URL parameter required') unless url
        return bad_request_response('URL too long') if url.length > 2048
        return bad_request_response('Invalid URL format') unless Auth.valid_url?(url)

        return handle_public_feed_access(router, feed_id, feed_token, url) if feed_token

        handle_authenticated_feed_access(router, url)
      rescue StandardError => error
        handle_auto_source_error(error)
      end

      def handle_authenticated_feed_access(router, url)
        token_data = Auth.authenticate(router)
        return unauthorized_response unless token_data

        return access_denied_response(url) unless AutoSource.url_allowed_for_token?(token_data, url)

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed_content(url, strategy)

        set_auto_source_headers
        rss_content.to_s
      end

      def handle_public_feed_access(router, _feed_id, feed_token, url)
        # Validate feed token and URL
        return access_denied_response(url) unless Auth.feed_url_allowed?(feed_token, url)

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed_content(url, strategy)

        set_auto_source_headers
        rss_content.to_s
      rescue StandardError => error
        handle_auto_source_error(error)
      end

      def handle_create_feed(router)
        return method_not_allowed_response unless router.post?

        token_data = Auth.authenticate(router)
        return unauthorized_response unless token_data

        url = router.params['url']
        return bad_request_response('URL parameter required') unless url

        return access_denied_response(url) unless AutoSource.url_allowed_for_token?(token_data, url)

        create_feed_response(url, token_data, router.params)
      rescue StandardError => error
        handle_auto_source_error(error)
      end

      def create_feed_response(url, token_data, params)
        name = params['name'] || "Auto-generated feed for #{url}"
        strategy = params['strategy'] || 'ssrf_filter'

        feed_data = AutoSource.create_stable_feed(name, url, token_data, strategy)
        return internal_error_response unless feed_data

        response['Content-Type'] = 'application/json'
        JSON.generate(feed_data)
      end

      def handle_list_feeds(router)
        token_data = Auth.authenticate(router)
        return unauthorized_response unless token_data

        # For stateless system, we can't list feeds without storage
        # Return empty array for now
        response['Content-Type'] = 'application/json'
        JSON.generate([])
      end

      def handle_legacy_auto_source_feed(router, encoded_url)
        token_data = AutoSource.authenticate_with_token(router)
        return unauthorized_response unless token_data
        return forbidden_origin_response unless AutoSource.allowed_origin?(router)

        process_legacy_auto_source_request(router, encoded_url, token_data)
      rescue StandardError => error
        handle_auto_source_error(error)
      end

      def process_legacy_auto_source_request(router, encoded_url, token_data)
        decoded_url = validate_and_decode_base64(encoded_url)
        return bad_request_response('Invalid URL encoding') unless decoded_url
        return bad_request_response('Invalid URL format') unless Auth.valid_url?(decoded_url)
        return access_denied_response(decoded_url) unless AutoSource.url_allowed_for_token?(token_data, decoded_url)

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed(encoded_url, strategy)
        set_auto_source_headers
        rss_content.to_s
      end

      def handle_auto_source_error(error)
        response.status = 500
        response['Content-Type'] = CONTENT_TYPE_RSS
        AutoSource.error_feed(error.message)
      end

      # Health check route helpers
      def handle_health_check(router)
        token_data = Auth.authenticate(router)
        health_check_account = HealthCheck.find_health_check_account

        if token_data && health_check_account && token_data[:token] == health_check_account[:token]
          response['Content-Type'] = 'text/plain'
          HealthCheck.run
        else
          health_check_unauthorized
        end
      end
    end
  end
end
