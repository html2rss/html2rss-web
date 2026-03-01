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
require_relative 'app/flags'
require_relative 'app/cache_ttl'
require_relative 'app/exceptions'
require_relative 'app/xml_builder'
require_relative 'app/error_responder'
require_relative 'app/security_logger'
require_relative 'app/observability'
require_relative 'app/app_context'
require_relative 'app/request_context_middleware'
require_relative 'app/api/v1/feeds'
require_relative 'app/api/v1/health'
require_relative 'app/api/v1/strategies'
require_relative 'app/ssrf_filter_strategy'
require_relative 'app/http_cache'
require_relative 'app/feed_request_handler'
require_relative 'app/feed_route_handler'
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
            <p>API available at <a href="/api/v1"><code>/api/v1</code></a></p>
          </body>
        </html>
      HTML
      def self.development? = EnvironmentValidator.development?
      class << self
        # @return [Html2rss::Web::AppContext::Context]
        def context
          AppContext.build
        end
      end

      def development? = self.class.development?
      EnvironmentValidator.validate_environment!
      EnvironmentValidator.validate_production_security!
      Flags.validate!

      Html2rss::RequestService.register_strategy(:ssrf_filter, SsrfFilterStrategy)
      Html2rss::RequestService.default_strategy_name = :ssrf_filter
      Html2rss::RequestService.unregister_strategy(:faraday)
      opts.merge!(check_dynamic_arity: false, check_arity: :warn)
      use RequestContextMiddleware
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

        ErrorResponder.respond(request: request, response: response, error: error)
      end

      route do |r|
        context = self.class.context
        r.public

        context.routes_api_v1.call(r, context: context) ||
          context.routes_static.call(r,
                                     feed_handler: lambda { |router_ctx, feed_name|
                                       FeedRouteHandler.call(context: context, router: router_ctx, feed_name: feed_name)
                                     },
                                     index_renderer: ->(router_ctx) { render_index_page(router_ctx) })
      end

      private

      def render_index_page(router)
        index_path = 'public/frontend/index.html'
        router.response['Content-Type'] = 'text/html'
        File.exist?(index_path) ? File.read(index_path) : FALLBACK_HTML
      end
    end
  end
end
