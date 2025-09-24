# frozen_string_literal: true

require 'roda'
require 'rack/cache'
require 'json'
require 'base64'

require 'html2rss'
require_relative 'app/environment_validator'
require_relative 'app/auth'
require_relative 'app/auto_source'
require_relative 'app/feeds'
require_relative 'app/health_check'
require_relative 'app/local_config'
require_relative 'app/exceptions'
require_relative 'app/xml_builder'
require_relative 'app/security_logger'
require_relative 'app/api/v1/feeds'
require_relative 'app/api/v1/health'
require_relative 'app/api/v1/strategies'
require_relative 'app/ssrf_filter_strategy'
require_relative 'app/http_cache'

module Html2rss
  module Web
    ##
    # Roda app serving RSS feeds via html2rss
    class App < Roda
      CONTENT_TYPE_RSS = 'application/xml'

      def self.development? = ENV['RACK_ENV'] == 'development'
      def development? = self.class.development?

      EnvironmentValidator.validate_environment!
      EnvironmentValidator.validate_production_security!

      # Inline Roda configuration
      Html2rss::RequestService.register_strategy(:ssrf_filter, SsrfFilterStrategy)
      Html2rss::RequestService.default_strategy_name = :ssrf_filter
      Html2rss::RequestService.unregister_strategy(:faraday)
      opts[:check_dynamic_arity] = false
      opts[:check_arity] = :warn
      use Rack::Cache, metastore: 'file:./tmp/rack-cache-meta', entitystore: 'file:./tmp/rack-cache-body',
                       verbose: false

      plugin :content_security_policy do |csp|
        csp.default_src :none
        csp.style_src :self, "'unsafe-inline'"
        csp.script_src :self, "'unsafe-inline'"
        csp.connect_src :self
        csp.img_src :self, 'data:', 'blob:'
        csp.font_src :self, 'data:'
        csp.form_action :self
        csp.base_uri :none
        csp.frame_ancestors development? ? ['http://localhost:*', 'https://localhost:*'] : :none
        csp.frame_src :self
        csp.object_src :none
        csp.media_src :none
        csp.manifest_src :none
        csp.worker_src :none
        csp.child_src :none
        csp.block_all_mixed_content
        csp.upgrade_insecure_requests
      end

      plugin :default_headers, {
        'X-Content-Type-Options' => 'nosniff',
        'X-XSS-Protection' => '1; mode=block',
        'X-Frame-Options' => 'SAMEORIGIN',
        'X-Permitted-Cross-Domain-Policies' => 'none',
        'Referrer-Policy' => 'strict-origin-when-cross-origin',
        'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()',
        'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains; preload',
        'Cross-Origin-Embedder-Policy' => 'require-corp',
        'Cross-Origin-Opener-Policy' => 'same-origin',
        'Cross-Origin-Resource-Policy' => 'same-origin',
        'X-DNS-Prefetch-Control' => 'off',
        'X-Download-Options' => 'noopen'
      }

      plugin :json_parser
      plugin :public
      plugin :exception_page
      plugin :error_handler do |error|
        next exception_page(error) if development?

        # Simple error handling for production
        status = case error
                 when UnauthorizedError then 401
                 when BadRequestError then 400
                 when ForbiddenError then 403
                 when NotFoundError then 404
                 else 500
                 end

        response.status = status

        if request.path.start_with?('/api/v1/')
          response['Content-Type'] = 'application/json'
          error_code = case error
                       when UnauthorizedError then 'UNAUTHORIZED'
                       when BadRequestError then 'BAD_REQUEST'
                       when ForbiddenError then 'FORBIDDEN'
                       when NotFoundError then 'NOT_FOUND'
                       else 'INTERNAL_SERVER_ERROR'
                       end
          JSON.generate({ success: false, error: { message: error.message, code: error_code } })
        else
          response['Content-Type'] = 'application/xml'
          XmlBuilder.build_error_feed(message: error.message)
        end
      end

      @show_backtrace = development? && !ENV['CI']

      route do |r|
        r.public

        r.on 'api', 'v1' do
          r.response['Content-Type'] = 'application/json'

          r.on 'health' do
            r.get 'ready' do
              JSON.generate(Api::V1::Health.ready(r))
            end
            r.get 'live' do
              JSON.generate(Api::V1::Health.live(r))
            end
            r.get do
              JSON.generate(Api::V1::Health.show(r))
            end
          end

          r.on 'strategies' do
            r.get String do |strategy_id|
              JSON.generate(Api::V1::Strategies.show(r, strategy_id))
            end
            r.get do
              JSON.generate(Api::V1::Strategies.index(r))
            end
          end

          r.on 'feeds' do
            r.get String do |token|
              result = Api::V1::Feeds.show(r, token)
              result.is_a?(Hash) ? JSON.generate(result) : result
            end
            r.post do
              JSON.generate(Api::V1::Feeds.create(r))
            end
            r.get do
              JSON.generate(Api::V1::Feeds.index(r))
            end
          end

          r.get 'docs' do
            docs_path = 'docs/api/v1/openapi.yaml'
            if File.exist?(docs_path)
              r.response['Content-Type'] = 'text/yaml'
              File.read(docs_path)
            else
              r.response.status = 404
              JSON.generate({ success: false, error: { message: 'Documentation not found' } })
            end
          end

          r.get do
            JSON.generate({ success: true,
                            data: { api: { name: 'html2rss-web API', version: '1.0.0',
                                           description: 'RESTful API for converting websites to RSS feeds' } } })
          end
        end

        # Backward compatibility: /{feed_name} (no auth required)
        r.get String do |feed_name|
          # Skip static file requests
          next if feed_name.include?('.') && !feed_name.end_with?('.xml', '.rss')

          # Route to feed generation without auth for backward compatibility
          handle_feed_generation(r, feed_name)
        end
        r.get 'health_check.txt' do
          handle_health_check(r)
        end
        r.root do
          index_path = 'public/frontend/index.html'
          response['Content-Type'] = 'text/html'
          File.exist?(index_path) ? File.read(index_path) : fallback_html
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
                body{font-family:system-ui,sans-serif;max-width:800px;margin:0 auto;padding:2rem;line-height:1.6}
                h1{color:#111827}
                code{background:#f3f4f6;padding:0.2rem 0.4rem;border-radius:0.25rem}
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

      def handle_feed_generation(router, feed_name)
        rss_content = Feeds.generate_feed(feed_name, router.params)
        ttl = LocalConfig.find(feed_name)&.dig(:channel, :ttl) || 3600
        router.response['Content-Type'] = 'application/xml'
        router.response['Cache-Control'] = "public, max-age=#{ttl}"
        rss_content
      end

      def generate_rss_response(router, url)
        router.response['Content-Type'] = 'application/xml'
        HttpCache.expires(router.response, 600, cache_control: 'public')

        AutoSource.generate_feed_content(url, router.params['strategy'] || 'ssrf_filter').to_s
      end

      def error_response(router, status, message)
        router.response.status = status
        message
      end

      def handle_health_check(router)
        health_response = Api::V1::Health.show(router)
        if health_response[:success] && health_response.dig(:data, :health, :status) == 'healthy'
          router.response['Content-Type'] = 'text/plain'
          'success'
        else
          router.response.status = 500
          router.response['Content-Type'] = 'text/plain'
          'health check failed'
        end
      rescue StandardError => error
        router.response.status = 500

        router.response['Content-Type'] = 'text/plain'
        "health check error: #{error.message}"
      end
    end
  end
end
