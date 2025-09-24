# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Custom exceptions for clean error handling
    # These map to HTTP status codes and are handled by Roda's error_handler

    # HTTP 401 - Authentication required
    class UnauthorizedError < StandardError
      def initialize(message = 'Authentication required')
        super
      end
    end

    # HTTP 400 - Invalid request
    class BadRequestError < StandardError
      def initialize(message = 'Bad Request')
        super
      end
    end

    # HTTP 403 - Access denied
    class ForbiddenError < StandardError
      def initialize(message = 'Forbidden')
        super
      end
    end

    # HTTP 404 - Resource not found
    class NotFoundError < StandardError
      def initialize(message = 'Not Found')
        super
      end
    end

    # HTTP 405 - Method not allowed
    class MethodNotAllowedError < StandardError
      def initialize(message = 'Method Not Allowed')
        super
      end
    end

    # HTTP 500 - Server error
    class InternalServerError < StandardError
      def initialize(message = 'Internal Server Error')
        super
      end
    end
  end
end
