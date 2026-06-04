# frozen_string_literal: true

module Html2rss
  class RequestService
    ##
    # Defines the interface of every request strategy.
    class Strategy
      ##
      # @param ctx [Context] the context for the request
      def initialize(ctx)
        @ctx = ctx
      end

      ##
      # Executes the request.
      # @return [Response] the response from the strategy
      # @raise [NotImplementedError] if the method is not implemented by the subclass
      def execute
        raise NotImplementedError, 'Subclass must implement #execute'
      end

      private

      # @return [Context] the context for the request
      attr_reader :ctx
    end
  end
end
