# frozen_string_literal: true

require_relative '../app/response_context'

module Html2rss
  module Web
    ##
    # Response helper methods for the main App class
    # Now uses unified ResponseContext to eliminate duplication
    module ResponseHelpers
      module_function

      ##
      # Return unauthorized response
      def unauthorized_response
        ResponseContext.new(response).unauthorized_response
      end

      ##
      # Return forbidden origin response
      def forbidden_origin_response
        ResponseContext.new(response).forbidden_origin_response
      end

      ##
      # Return access denied response
      # @param url [String] URL that was denied
      def access_denied_response(url)
        ResponseContext.new(response).access_denied_response(url)
      end

      ##
      # Return not found response
      def not_found_response
        ResponseContext.new(response).not_found_response
      end

      ##
      # Return bad request response
      # @param message [String] error message
      def bad_request_response(message)
        ResponseContext.new(response).bad_request_response(message)
      end

      def method_not_allowed_response
        ResponseContext.new(response).method_not_allowed_response
      end

      def internal_error_response
        ResponseContext.new(response).internal_error_response
      end

      def configure_auto_source_headers
        ResponseContext.new(response).configure_auto_source_headers
      end

      # Methods that work with router objects (for route modules)
      def unauthorized_response_with_router(router)
        ResponseContext.new(router).unauthorized_response
      end

      def forbidden_origin_response_with_router(router)
        ResponseContext.new(router).forbidden_origin_response
      end

      def access_denied_response_with_router(router, url)
        ResponseContext.new(router).access_denied_response(url)
      end

      def not_found_response_with_router(router)
        ResponseContext.new(router).not_found_response
      end

      def bad_request_response_with_router(router, message)
        ResponseContext.new(router).bad_request_response(message)
      end

      def method_not_allowed_response_with_router(router)
        ResponseContext.new(router).method_not_allowed_response
      end

      def internal_error_response_with_router(router)
        ResponseContext.new(router).internal_error_response
      end

      def configure_auto_source_headers_with_router(router)
        ResponseContext.new(router).configure_public_feed_headers
      end
    end
  end
end
