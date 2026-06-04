# frozen_string_literal: true

module Html2rss
  class RequestService
    ##
    # Tracks how many outbound requests a single feed build may still perform.
    class Budget
      ##
      # @param max_requests [Integer] the maximum number of requests allowed
      def initialize(max_requests:)
        unless max_requests.is_a?(Integer) && max_requests.positive?
          raise ArgumentError, 'max_requests must be positive'
        end

        @remaining = max_requests
        @mutex = Mutex.new
      end

      ##
      # Consumes one request from the budget.
      #
      # @return [Integer] remaining request count after consumption
      # @raise [RequestBudgetExceeded] if no requests remain
      def consume!
        @mutex.synchronize do
          raise RequestBudgetExceeded, 'Request budget exhausted' if @remaining.zero?

          @remaining -= 1
        end
      end

      ##
      # @return [Integer] requests still available
      def remaining
        @mutex.synchronize { @remaining }
      end
    end
  end
end
