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
require_relative 'app/local_config'
require_relative 'app/exceptions'
require_relative 'app/xml_builder'
require_relative 'app/security_logger'
require_relative 'app/api/v1/feeds'
require_relative 'app/api/v1/health'
require_relative 'app/api/v1/strategies'
require_relative 'app/ssrf_filter_strategy'
require_relative 'app/http_cache'
require_relative 'app/routes/api_v1'
require_relative 'app/routes/static'

module Html2rss
  module Web
    ##
    # Roda app serving RSS feeds via html2rss
    class App < Roda
      FALLBACK_HTML = <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <title>html2rss-web</title>
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <meta name="robots" content="noindex,nofollow">
          </head>
          <body>
            <h1>html2rss-web</h1>
            <p>Convert websites to RSS feeds</p>
            <p>API available at <code>/api/</code></p>
          </body>
        </html>
      HTML
      def self.development? = EnvironmentValidator.development?
      def development? = self.class.development?
      EnvironmentValidator.validate_environment!
      EnvironmentValidator.validate_production_security!

      Html2rss::RequestService.register_strategy(:ssrf_filter, SsrfFilterStrategy)
      Html2rss::RequestService.default_strategy_name = :ssrf_filter
      Html2rss::RequestService.unregister_strategy(:faraday)
      opts.merge!(check_dynamic_arity: false, check_arity: :warn)
      use Rack::Cache, metastore: 'file:./tmp/rack-cache-meta', entitystore: 'file:./tmp/rack-cache-body',
                       verbose: development?

      plugin :content_security_policy do |csp|
        csp.default_src :none
        csp.style_src :self, "'unsafe-inline'"
        csp.script_src :self
        csp.connect_src :self
        csp.img_src :self
        csp.font_src :self
        csp.form_action :self
        csp.base_uri :none
        if development?
          csp.frame_ancestors 'http://localhost:*', 'https://localhost:*',
                              'http://127.0.0.1:*', 'https://127.0.0.1:*'
        else
          csp.frame_ancestors :none
        end
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

        error_code = error.respond_to?(:code) ? error.code : 'INTERNAL_SERVER_ERROR'

        response.status = error.respond_to?(:status) ? error.status : 500

        if request.path.start_with?('/api/v1/')
          response['Content-Type'] = 'application/json'
          JSON.generate({ success: false, error: { message: error.message, code: error_code } })
        else
          response['Content-Type'] = 'application/xml'
          XmlBuilder.build_error_feed(message: error.message)
        end
      end

      @show_backtrace = development? && !ENV['CI']

      route do |r|
        r.public

        Routes::ApiV1.call(r)
        Routes::Static.call(r,
                            feed_handler: ->(router_ctx, feed_name) { handle_feed_generation(router_ctx, feed_name) },
                            index_renderer: ->(router_ctx) { render_index_page(router_ctx) })
      end

      private

      def handle_feed_generation(router, feed_name)
        rss_content = Feeds.generate_feed(feed_name, router.params)
        ttl_minutes = LocalConfig.find(feed_name)&.dig(:channel, :ttl)
        ttl_seconds = ttl_minutes ? ttl_minutes * 60 : 3600
        router.response['Content-Type'] = 'application/xml'
        HttpCache.expires(router.response, ttl_seconds, cache_control: 'public')
        rss_content
      end

      def render_index_page(router)
        index_path = 'public/frontend/index.html'
        router.response['Content-Type'] = 'text/html'
        File.exist?(index_path) ? File.read(index_path) : FALLBACK_HTML
      end
    end
  end
end
