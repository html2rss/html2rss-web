# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Base error type mapped to an HTTP status and API error code.
    class HttpError < StandardError
      DEFAULT_MESSAGE = 'Internal Server Error'
      STATUS = 500
      CODE = 'INTERNAL_SERVER_ERROR'

      # @param message [String]
      # @return [void]
      def initialize(message = self.class::DEFAULT_MESSAGE)
        super
      end

      # @return [Integer]
      def status
        self.class::STATUS
      end

      # @return [String]
      def code
        self.class::CODE
      end
    end
  end
end
