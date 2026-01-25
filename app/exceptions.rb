# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Custom exceptions for clean error handling
    # These map to HTTP status codes and are handled by Roda's error_handler

    class HttpError < StandardError
      DEFAULT_MESSAGE = 'Internal Server Error'
      STATUS = 500
      CODE = 'INTERNAL_SERVER_ERROR'

      def initialize(message = self.class::DEFAULT_MESSAGE)
        super
      end

      def status
        self.class::STATUS
      end

      def code
        self.class::CODE
      end
    end

    # HTTP 401 - Authentication required
    class UnauthorizedError < HttpError
      DEFAULT_MESSAGE = 'Authentication required'
      STATUS = 401
      CODE = 'UNAUTHORIZED'
    end

    # HTTP 400 - Invalid request
    class BadRequestError < HttpError
      DEFAULT_MESSAGE = 'Bad Request'
      STATUS = 400
      CODE = 'BAD_REQUEST'
    end

    # HTTP 403 - Access denied
    class ForbiddenError < HttpError
      DEFAULT_MESSAGE = 'Forbidden'
      STATUS = 403
      CODE = 'FORBIDDEN'
    end

    # HTTP 404 - Resource not found
    class NotFoundError < HttpError
      DEFAULT_MESSAGE = 'Not Found'
      STATUS = 404
      CODE = 'NOT_FOUND'
    end

    # HTTP 405 - Method not allowed
    class MethodNotAllowedError < HttpError
      DEFAULT_MESSAGE = 'Method Not Allowed'
      STATUS = 405
      CODE = 'METHOD_NOT_ALLOWED'
    end

    # HTTP 500 - Server error
    class InternalServerError < HttpError
    end
  end
end
