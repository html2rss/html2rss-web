# frozen_string_literal: true

require_relative 'xml_builder'

module Html2rss
  module Web
    ##
    # Unified response context that eliminates duplication in response handling
    # Works with both direct response objects and Roda router objects
    class ResponseContext
      attr_reader :response, :router

      def initialize(response_or_router)
        if response_or_router.respond_to?(:response)
          @router = response_or_router
          @response = response_or_router.response
        else
          @response = response_or_router
          @router = nil
        end
      end

      ##
      # Set response status and content type
      # @param status [Integer] HTTP status code
      # @param content_type [String] MIME type
      def set_headers(status, content_type = 'application/xml')
        @response.status = status
        @response['Content-Type'] = content_type
      end

      ##
      # Return unauthorized response
      def unauthorized_response
        set_headers(401)
        @response['WWW-Authenticate'] = 'Basic realm="Auto Source"'
        XmlBuilder.build_error_feed(message: 'Unauthorized')
      end

      ##
      # Return forbidden origin response
      def forbidden_origin_response
        set_headers(403)
        XmlBuilder.build_error_feed(message: 'Origin is not allowed.')
      end

      ##
      # Return access denied response
      # @param url [String] URL that was denied
      def access_denied_response(url)
        set_headers(403)
        XmlBuilder.build_access_denied_feed(url)
      end

      ##
      # Return not found response
      def not_found_response
        set_headers(404)
        XmlBuilder.build_error_feed(message: 'Feed not found', title: 'Not Found')
      end

      ##
      # Return bad request response
      # @param message [String] error message
      def bad_request_response(message)
        set_headers(400)
        XmlBuilder.build_error_feed(message: message, title: 'Bad Request')
      end

      ##
      # Return method not allowed response
      def method_not_allowed_response
        set_headers(405)
        XmlBuilder.build_error_feed(message: 'Method Not Allowed')
      end

      ##
      # Return internal server error response
      def internal_error_response
        set_headers(500)
        XmlBuilder.build_error_feed(message: 'Internal Server Error')
      end

      ##
      # Configure auto source headers
      def configure_auto_source_headers
        @response['Content-Type'] = 'application/xml'
        @response['Cache-Control'] = 'private, must-revalidate, no-cache, no-store, max-age=0'
        @response['X-Content-Type-Options'] = 'nosniff'
        @response['X-XSS-Protection'] = '1; mode=block'
      end

      ##
      # Configure public feed headers
      def configure_public_feed_headers
        @response['Content-Type'] = 'application/xml'
        @response['Cache-Control'] = 'public, max-age=3600'
        @response['X-Content-Type-Options'] = 'nosniff'
        @response['X-XSS-Protection'] = '1; mode=block'
      end

      ##
      # Set RSS response headers with TTL
      # @param ttl [Integer] time to live in seconds
      def set_rss_headers(ttl: 3600)
        @response['Content-Type'] = 'application/xml'
        @response['Cache-Control'] = "public, max-age=#{ttl}"
      end

      ##
      # Set JSON response headers
      def set_json_headers
        @response['Content-Type'] = 'application/json'
      end

      ##
      # Set cache headers
      # @param ttl [Integer] time to live in seconds
      def cache_headers=(ttl)
        @response['Cache-Control'] = "public, max-age=#{ttl}"
      end
    end
  end
end
