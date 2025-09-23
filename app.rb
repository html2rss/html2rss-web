# frozen_string_literal: true

require 'roda'
require 'rack/cache'
require 'json'
require 'base64'

require 'html2rss'
require_relative 'app/environment_validator'
require_relative 'app/roda_config'
require_relative 'app/auth'
require_relative 'app/auto_source'
require_relative 'app/feeds'
require_relative 'app/health_check'
require_relative 'app/local_config'
require_relative 'app/exceptions'
require_relative 'app/xml_builder'
require_relative 'app/security_logger'
require_relative 'app/api/v1/router'
require_relative 'app/api/v1/health'

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
      plugin :json_parser
      plugin :public
      plugin :exception_page
      plugin :error_handler do |error|
        next exception_page(error) if development?

        # Map custom exceptions to HTTP status codes
        status = case error
                 when UnauthorizedError then 401
                 when BadRequestError then 400
                 when ForbiddenError then 403
                 when NotFoundError then 404
                 when MethodNotAllowedError then 405
                 else 500
                 end

        response.status = status
        response['Content-Type'] = 'application/xml'
        require_relative 'app/xml_builder'
        XmlBuilder.build_error_feed(message: error.message)
      end

      # Routes are now defined directly in this file for better clarity

      @show_backtrace = development? && !ENV['CI']

      route do |r|
        r.public

        # RESTful API v1 routes (must come before legacy routes)
        r.on 'api', 'v1' do
          Api::V1::Router.route(r)
        end

        # Legacy API routes (backward compatibility)
        r.on 'api' do
          r.response['Content-Type'] = 'application/json'

          r.get 'feeds.json' do
            r.response['Cache-Control'] = 'public, max-age=300'
            JSON.generate(Feeds.list_feeds)
          end

          r.get 'strategies.json' do
            r.response['Cache-Control'] = 'public, max-age=3600'
            JSON.generate(list_available_strategies)
          end

          # Only match legacy feed names (not v1 paths)
          r.get String do |feed_name|
            # Skip if this looks like a v1 path
            next if feed_name.start_with?('v1/')

            handle_feed_generation(r, feed_name)
          end
        end

        # Auto source routes
        r.on 'auto_source' do
          if AutoSource.enabled?
            r.post 'create' do
              handle_create_feed(r)
            end

            r.get String do |encoded_url|
              handle_legacy_feed(r, encoded_url)
            end
          else
            r.response.status = 400
            'Auto source feature is disabled'
          end
        end

        # Feed routes
        r.on 'feeds' do
          r.get String do |feed_id|
            handle_stable_feed(r, feed_id)
          end
        end

        # Health check
        r.get 'health_check.txt' do
          handle_health_check(r)
        end

        # Root route
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

      private

      def list_available_strategies
        strategies = Html2rss::RequestService.strategy_names.map do |name|
          {
            name: name.to_s,
            display_name: name.to_s.split('_').map(&:capitalize).join(' ')
          }
        end

        { strategies: strategies }
      end

      def handle_feed_generation(router, feed_name)
        rss_content = Feeds.generate_feed(feed_name, router.params)
        config = LocalConfig.find(feed_name)
        ttl = config.dig(:channel, :ttl) || 3600

        router.response['Content-Type'] = 'application/xml'
        router.response['Cache-Control'] = "public, max-age=#{ttl}"
        rss_content
      end

      def handle_create_feed(router)
        account = Auth.authenticate(router)
        unless account
          router.response.status = 401
          return 'Unauthorized'
        end

        url = router.params['url']
        unless url && Auth.valid_url?(url)
          router.response.status = 400
          return 'Bad Request'
        end

        unless Auth.url_allowed?(account, url)
          router.response.status = 403
          return 'Forbidden'
        end

        strategy = router.params['strategy'] || 'ssrf_filter'
        feed_data = AutoSource.create_stable_feed('Generated Feed', url, account, strategy)
        unless feed_data
          router.response.status = 500
          return 'Internal Server Error'
        end

        router.response['Content-Type'] = 'application/json'
        JSON.generate(feed_data)
      end

      def handle_legacy_feed(router, encoded_url)
        account = Auth.authenticate(router)
        unless account
          router.response.status = 401
          return 'Unauthorized'
        end

        unless AutoSource.allowed_origin?(router)
          router.response.status = 403
          return 'Forbidden'
        end

        decoded_url = Base64.urlsafe_decode64(encoded_url)
        unless decoded_url && Auth.valid_url?(decoded_url)
          router.response.status = 400
          return 'Bad Request'
        end

        unless AutoSource.url_allowed_for_token?(account, decoded_url)
          router.response.status = 403
          return 'Forbidden'
        end

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed_content(decoded_url, strategy)

        router.response['Content-Type'] = 'application/xml'
        rss_content.to_s
      rescue ArgumentError
        router.response.status = 400
        'Bad Request'
      end

      def handle_stable_feed(router, feed_id)
        feed_token = router.params['token']

        if feed_token
          handle_public_feed(router, feed_id, feed_token)
        else
          handle_authenticated_feed(router)
        end
      end

      def handle_public_feed(router, _feed_id, feed_token)
        url = router.params['url']
        unless url && Auth.valid_url?(url)
          router.response.status = 400
          return 'Bad Request'
        end

        unless Auth.feed_url_allowed?(feed_token, url)
          router.response.status = 403
          return 'Forbidden'
        end

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed_content(url, strategy)

        router.response['Content-Type'] = 'application/xml'
        rss_content.to_s
      end

      def handle_authenticated_feed(router)
        account = Auth.authenticate(router)
        unless account
          router.response.status = 401
          return 'Unauthorized'
        end

        url = router.params['url']
        unless url && Auth.valid_url?(url)
          router.response.status = 400
          return 'Bad Request'
        end

        unless Auth.url_allowed?(account, url)
          router.response.status = 403
          return 'Forbidden'
        end

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed_content(url, strategy)

        router.response['Content-Type'] = 'application/xml'
        rss_content.to_s
      end

      def handle_health_check(router)
        # Delegate to V1 API health endpoint to eliminate duplication

        health_response = Api::V1::Health.show(router)

        if health_response[:success] && health_response.dig(:data, :health, :status) == 'healthy'
          router.response['Content-Type'] = 'text/plain'
          'success'
        else
          router.response.status = 500
          router.response['Content-Type'] = 'text/plain'
          'health check failed'
        end
      rescue UnauthorizedError
        router.response.status = 401
        router.response['WWW-Authenticate'] = 'Bearer realm="Health Check"'
        router.response['Content-Type'] = 'application/xml'
        require_relative 'app/xml_builder'
        XmlBuilder.build_error_feed(message: 'Unauthorized', title: 'Health Check Unauthorized')
      rescue StandardError => error
        router.response.status = 500
        router.response['Content-Type'] = 'text/plain'
        "health check error: #{error.message}"
      end
    end
  end
end
