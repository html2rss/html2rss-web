# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Response helper methods for the main App class
    module ResponseHelpers
      module_function

      def unauthorized_response
        response.status = 401
        response['WWW-Authenticate'] = 'Basic realm="Auto Source"'
        'Unauthorized'
      end

      def forbidden_origin_response
        response.status = 403
        'Origin is not allowed.'
      end

      def access_denied_response(url)
        response.status = 403
        response['Content-Type'] = 'application/xml'
        AutoSource.access_denied_feed(url)
      end

      def not_found_response
        response.status = 404
        'Feed not found'
      end

      def bad_request_response(message)
        response.status = 400
        message
      end

      def method_not_allowed_response
        response.status = 405
        'Method Not Allowed'
      end

      def internal_error_response
        response.status = 500
        'Internal Server Error'
      end

      def set_auto_source_headers
        response['Content-Type'] = 'application/xml'
        response['Cache-Control'] = 'private, must-revalidate, no-cache, no-store, max-age=0'
        response['X-Content-Type-Options'] = 'nosniff'
        response['X-XSS-Protection'] = '1; mode=block'
      end

      def health_check_unauthorized
        response.status = 401
        response['WWW-Authenticate'] = 'Bearer realm="Health Check"'
        'Unauthorized'
      end
    end
  end
end
