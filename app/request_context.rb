# frozen_string_literal: true

require_relative 'auth'
require_relative 'response_context'

module Html2rss
  module Web
    ##
    # Request context that centralizes authentication and request handling
    # Eliminates repetitive authentication patterns across route modules
    class RequestContext
      attr_reader :router, :params, :account, :authenticated, :response_context

      def initialize(router)
        @router = router
        @params = router.params
        @account = Auth.authenticate(router)
        @authenticated = !@account.nil?
        @response_context = ResponseContext.new(router)
      end

      ##
      # Require authentication, raise error if not authenticated
      # @return [Hash] account data
      # @raise [UnauthorizedError] if not authenticated
      def require_auth!
        raise UnauthorizedError, 'Authentication required' unless authenticated

        @account
      end

      ##
      # Check if URL is allowed for the current account
      # @param url [String] URL to check
      # @return [Boolean] true if allowed
      def url_allowed?(url)
        return false unless authenticated

        Auth.url_allowed?(@account, url)
      end

      ##
      # Validate URL parameter
      # @param url_param [String] parameter name containing URL
      # @return [String, nil] validated URL or nil if invalid
      def validate_url_param(url_param = 'url')
        url = @params[url_param]
        return nil unless url
        return nil if url.length > 2048
        return nil unless Auth.valid_url?(url)

        url
      end

      ##
      # Validate required parameter
      # @param param_name [String] parameter name
      # @return [String, nil] parameter value or nil if missing
      def validate_required_param(param_name)
        value = @params[param_name]
        return nil if value.nil? || value.empty?

        value
      end

      ##
      # Check if request method is allowed
      # @param allowed_methods [Array<String>] allowed HTTP methods
      # @return [Boolean] true if method is allowed
      def method_allowed?(*allowed_methods)
        allowed_methods.include?(@router.request_method)
      end

      ##
      # Require specific HTTP method
      # @param method [String] required HTTP method
      # @raise [MethodNotAllowedError] if method doesn't match
      def require_method!(method)
        raise MethodNotAllowedError, "Method #{method} required" unless method_allowed?(method)
      end

      ##
      # Handle authentication with automatic error response
      # @return [Hash, nil] account data or nil if not authenticated
      def authenticate_or_respond
        return @account if authenticated

        @response_context.unauthorized_response
        nil
      end

      ##
      # Handle URL validation with automatic error response
      # @param url_param [String] parameter name containing URL
      # @return [String, nil] validated URL or nil if invalid
      def validate_url_or_respond(url_param = 'url')
        url = validate_url_param(url_param)
        return url if url

        if @params[url_param].nil?
          @response_context.bad_request_response("#{url_param.upcase} parameter required")
        elsif @params[url_param].length > 2048
          @response_context.bad_request_response('URL too long')
        else
          @response_context.bad_request_response('Invalid URL format')
        end
        nil
      end

      ##
      # Handle URL permission check with automatic error response
      # @param url [String] URL to check
      # @return [Boolean] true if allowed
      def check_url_permission_or_respond(url)
        return true if url_allowed?(url)

        @response_context.access_denied_response(url)
        false
      end

      ##
      # Handle method validation with automatic error response
      # @param method [String] required HTTP method
      # @return [Boolean] true if method is correct
      def check_method_or_respond(method)
        return true if method_allowed?(method)

        @response_context.method_not_allowed_response
        false
      end

      ##
      # Get strategy parameter with default
      # @return [String] strategy name
      def strategy
        @params['strategy'] || 'ssrf_filter'
      end

      ##
      # Get name parameter with default
      # @param url [String] URL to use in default name
      # @return [String] name
      def name(url = nil)
        @params['name'] || (url ? "Auto-generated feed for #{url}" : 'Auto-generated feed')
      end

      ##
      # Check if this is a development environment
      # @return [Boolean] true if development
      def development?
        ENV.fetch('RACK_ENV', nil) == 'development'
      end

      ##
      # Get client IP address
      # @return [String] IP address
      def client_ip
        @router.ip
      end

      ##
      # Get user agent
      # @return [String] user agent string
      def user_agent
        @router.user_agent
      end
    end

    ##
    # Custom error classes for better error handling
    class UnauthorizedError < StandardError; end
    class MethodNotAllowedError < StandardError; end
    class ValidationError < StandardError; end
  end
end
