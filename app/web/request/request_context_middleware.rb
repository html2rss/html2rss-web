# frozen_string_literal: true

require 'rack/request'
require 'securerandom'
require 'time'
require_relative '../security/log_sanitizer'

module Html2rss
  module Web
    ##
    # Rack middleware that initializes request correlation context.
    class RequestContextMiddleware
      ROUTE_PREFIX_TO_GROUP = {
        '/api/v1' => 'api_v1'
      }.freeze

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
      # @return [String]
      def route_group_for(path)
        ROUTE_PREFIX_TO_GROUP.each do |prefix, group|
          return group if path == prefix || path.start_with?("#{prefix}/")
        end

        'static'
      end

      # @param request [Rack::Request]
      # @return [Html2rss::Web::RequestContext::Context]
      def build_context(request)
        path = request.path_info.to_s
        RequestContext::Context.new(
          request_id: request_id_for(request),
          path: LogSanitizer.sanitize_path(path),
          http_method: request.request_method.to_s.upcase,
          route_group: route_group_for(path),
          actor: nil,
          strategy: request.params['strategy'],
          started_at: Time.now.utc.iso8601
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
