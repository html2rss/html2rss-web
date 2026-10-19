# frozen_string_literal: true

require 'rack/request'
require 'securerandom'
require 'time'

module Html2rss
  module Web
    ##
    # Rack middleware that initializes request correlation context.
    class RequestContextMiddleware
      HEALTH_PATHS = %w[
        /api/v1/health
        /api/v1/health/live
        /api/v1/health/ready
      ].freeze
      FEED_RENDER_PATH = %r{\A/api/v1/feeds/[^/]+\z}

      # @param app [#call]
      def initialize(app)
        @app = app
      end

      # @param env [Hash]
      # @return [Array<(Integer, Hash, #each)>]
      def call(env)
        request = Rack::Request.new(env)
        context = build_context(request)
        env['html2rss.request_context'] = context
        RequestContext.set!(context)
        call_app_with_request_id(env, context.request_id)
      ensure
        RequestContext.clear!
      end

      private

      # @param request [Rack::Request]
      # @return [String]
      def request_id_for(request)
        incoming = request.get_header('HTTP_X_REQUEST_ID').to_s.strip
        return incoming unless incoming.empty?

        SecureRandom.hex(8)
      end

      # @param path [String]
      # @param http_method [String]
      # @return [String]
      def route_group_for(path, http_method)
        return 'health' if HEALTH_PATHS.include?(path)

        api_route_group(path, http_method)
      end

      # @param path [String]
      # @param http_method [String]
      # @return [String]
      def api_route_group(path, http_method)
        return 'catalog' if http_method == 'GET' && path == '/api/v1/configs'
        return 'feed_create' if http_method == 'POST' && path == '/api/v1/feeds'
        return 'feed_render' if http_method == 'GET' && FEED_RENDER_PATH.match?(path)

        'static'
      end

      # @param request [Rack::Request]
      # @return [Html2rss::Web::RequestContext::Context]
      def build_context(request)
        path = request.path_info.to_s
        http_method = request.request_method.to_s.upcase
        RequestContext::Context.new(
          request_id: request_id_for(request), path: LogSanitizer.sanitize_path(path),
          http_method: http_method, route_group: route_group_for(path, http_method),
          actor: nil, strategy: request.params['strategy'], started_at: Time.now.utc.iso8601
        )
      end

      # @param env [Hash]
      # @param request_id [String]
      # @return [Array<(Integer, Hash, #each)>]
      def call_app_with_request_id(env, request_id)
        status, headers, body = @app.call(env)
        headers['X-Request-Id'] ||= request_id
        [status, headers, body]
      end
    end
  end
end
