# frozen_string_literal: true

require_relative 'xml_builder'

module Html2rss
  module Web
    ##
    # Response helper methods for the main App class
    module ResponseHelpers
      module_function

      def unauthorized_response
        response.status = 401
        response['Content-Type'] = 'application/xml'
        response['WWW-Authenticate'] = 'Basic realm="Auto Source"'
        XmlBuilder.build_error_feed(message: 'Unauthorized')
      end

      def forbidden_origin_response
        response.status = 403
        response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: 'Origin is not allowed.')
      end

      def access_denied_response(url)
        response.status = 403
        response['Content-Type'] = 'application/xml'
        XmlBuilder.build_access_denied_feed(url)
      end

      def not_found_response
        response.status = 404
        response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: 'Feed not found', title: 'Not Found')
      end

      def bad_request_response(message)
        response.status = 400
        response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: message, title: 'Bad Request')
      end

      def method_not_allowed_response
        response.status = 405
        response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: 'Method Not Allowed')
      end

      def internal_error_response
        response.status = 500
        response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: 'Internal Server Error')
      end

      def configure_auto_source_headers
        response['Content-Type'] = 'application/xml'
        response['Cache-Control'] = 'private, must-revalidate, no-cache, no-store, max-age=0'
        response['X-Content-Type-Options'] = 'nosniff'
        response['X-XSS-Protection'] = '1; mode=block'
      end
    end
  end
end
