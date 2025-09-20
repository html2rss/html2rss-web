# frozen_string_literal: true

require_relative 'request_context'

module Html2rss
  module Web
    ##
    # Base route handler that consolidates common patterns across route modules
    # Eliminates repetitive authentication, validation, and error handling code
    module BaseRouteHandler
      module_function

      ##
      # Execute block with authentication requirement
      # @param context [RequestContext] request context
      # @yield [Hash] account data
      # @return [Object] result of block or error response
      def with_auth(context)
        account = context.authenticate_or_respond
        return context.response_context.unauthorized_response unless account

        yield(account)
      rescue StandardError => error
        handle_error(context, error)
      end

      ##
      # Execute block with URL validation
      # @param context [RequestContext] request context
      # @param url_param [String] parameter name containing URL
      # @yield [String] validated URL
      # @return [Object] result of block or error response
      def with_url_validation(context, url_param = 'url')
        url = context.validate_url_or_respond(url_param)
        return context.response_context.bad_request_response("#{url_param} parameter required") if url.nil?

        yield(url)
      rescue StandardError => error
        handle_error(context, error)
      end

      ##
      # Execute block with authentication and URL validation
      # @param context [RequestContext] request context
      # @param url_param [String] parameter name containing URL
      # @yield [Hash, String] account data and validated URL
      # @return [Object] result of block or error response
      def with_auth_and_url_validation(context, url_param = 'url')
        account = context.authenticate_or_respond
        return context.response_context.unauthorized_response unless account

        url = context.validate_url_or_respond(url_param)
        return context.response_context.bad_request_response("#{url_param.upcase} parameter required") unless url

        yield(account, url)
      rescue StandardError => error
        handle_error(context, error)
      end

      ##
      # Execute block with method validation
      # @param context [RequestContext] request context
      # @param method [String] required HTTP method
      # @yield [RequestContext] request context
      # @return [Object] result of block or error response
      def with_method_validation(context, method)
        return context.response_context.method_not_allowed_response unless context.check_method_or_respond(method)

        yield(context)
      rescue StandardError => error
        handle_error(context, error)
      end

      ##
      # Execute block with authentication, URL validation, and permission check
      # @param context [RequestContext] request context
      # @param url_param [String] parameter name containing URL
      # @yield [Hash, String] account data and validated URL
      # @return [Object] result of block or error response
      def with_full_validation(context, url_param = 'url')
        account = context.authenticate_or_respond
        return context.response_context.unauthorized_response unless account

        url = context.validate_url_or_respond(url_param)
        return context.response_context.bad_request_response("#{url_param.upcase} parameter required") unless url

        return context.response_context.access_denied_response(url) unless context.check_url_permission_or_respond(url)

        yield(account, url)
      rescue StandardError => error
        handle_error(context, error)
      end

      ##
      # Execute block with error handling
      # @param context [RequestContext] request context
      # @yield [RequestContext] request context
      # @return [Object] result of block or error response
      def with_error_handling(context)
        yield(context)
      rescue StandardError => error
        handle_error(context, error)
      end

      ##
      # Handle errors consistently across all route modules
      # @param context [RequestContext] request context
      # @param error [StandardError] error to handle
      # @return [String] error response
      def handle_error(context, error)
        case error
        when UnauthorizedError
          context.response_context.unauthorized_response
        when MethodNotAllowedError
          context.response_context.method_not_allowed_response
        when ValidationError
          context.response_context.bad_request_response(error.message)
        else
          handle_internal_error(context, error)
        end
      end

      def handle_internal_error(context, error)
        context.response_context.response.status = 500
        context.response_context.response['Content-Type'] = 'application/xml'
        require_relative 'xml_builder'
        XmlBuilder.build_error_feed(message: error.message)
      end

      ##
      # Create a new request context
      # @param router [Roda::Request] router instance
      # @return [RequestContext] new request context
      def create_context(router)
        RequestContext.new(router)
      end

      ##
      # Common pattern for JSON responses
      # @param context [RequestContext] request context
      # @param data [Hash] data to serialize
      # @return [String] JSON response
      def json_response(context, data)
        context.response_context.set_json_headers
        JSON.generate(data)
      end

      ##
      # Common pattern for RSS responses
      # @param context [RequestContext] request context
      # @param content [String] RSS content
      # @param ttl [Integer] cache TTL
      # @return [String] RSS response
      def rss_response(context, content, ttl: 3600)
        context.response_context.set_rss_headers(ttl: ttl)
        content.to_s
      end

      ##
      # Common pattern for auto source responses
      # @param context [RequestContext] request context
      # @param content [String] RSS content
      # @return [String] RSS response
      def auto_source_response(context, content)
        context.response_context.configure_auto_source_headers
        content.to_s
      end

      ##
      # Common pattern for public feed responses
      # @param context [RequestContext] request context
      # @param content [String] RSS content
      # @return [String] RSS response
      def public_feed_response(context, content)
        context.response_context.configure_public_feed_headers
        content.to_s
      end
    end
  end
end
