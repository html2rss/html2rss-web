# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Custom exceptions for clean error handling
    # These map to HTTP status codes and are handled by Roda's error_handler

    class UnauthorizedError < StandardError
      def initialize(message = 'Authentication required')
        super
      end
    end

    class BadRequestError < StandardError
      def initialize(message = 'Bad Request')
        super
      end
    end

    class ForbiddenError < StandardError
      def initialize(message = 'Forbidden')
        super
      end
    end

    class NotFoundError < StandardError
      def initialize(message = 'Not Found')
        super
      end
    end

    class MethodNotAllowedError < StandardError
      def initialize(message = 'Method Not Allowed')
        super
      end
    end

    class InternalServerError < StandardError
      def initialize(message = 'Internal Server Error')
        super
      end
    end
  end
end
