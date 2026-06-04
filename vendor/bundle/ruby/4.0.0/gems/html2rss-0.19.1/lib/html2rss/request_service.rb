# frozen_string_literal: true

require 'singleton'
require 'forwardable'

module Html2rss
  ##
  # Requests website URLs to retrieve their HTML for further processing.
  # Provides strategies, e.g. integrating Browserless.io.
  class RequestService
    include Singleton

    # Raised when an unknown request strategy is requested.
    class UnknownStrategy < Html2rss::Error; end
    # Raised when a URL cannot be parsed or validated.
    class InvalidUrl < Html2rss::Error; end
    # Raised when a URL uses an unsupported scheme.
    class UnsupportedUrlScheme < Html2rss::Error; end
    # Raised when a response type cannot be parsed.
    class UnsupportedResponseContentType < Html2rss::Error; end
    # Raised when request limits are exceeded.
    class RequestBudgetExceeded < Html2rss::Error; end
    # Raised when policy denies private-network access.
    class PrivateNetworkDenied < Html2rss::Error; end
    # Raised when cross-origin follow-up requests are denied.
    class CrossOriginFollowUpDenied < Html2rss::Error; end
    # Raised when a response exceeds configured size limits.
    class ResponseTooLarge < Html2rss::Error; end
    # Raised when blocked content surfaces are detected.
    class BlockedSurfaceDetected < Html2rss::Error; end
    # Raised when a request times out.
    class RequestTimedOut < Html2rss::Error; end
    # Raised when Browserless configuration is missing or invalid.
    class BrowserlessConfigurationError < Html2rss::Error; end
    # Raised when Browserless cannot be reached.
    class BrowserlessConnectionFailed < Html2rss::Error; end
    # Raised when Botasaurus configuration is missing or invalid.
    class BotasaurusConfigurationError < Html2rss::Error; end
    # Raised when Botasaurus cannot be reached or returns invalid payloads.
    class BotasaurusConnectionFailed < Html2rss::Error; end

    class << self
      extend Forwardable

      %i[default_strategy_name
         default_strategy_name=
         strategy_names
         register_strategy
         unregister_strategy
         strategy_registered?
         execute].each do |method|
        def_delegator :instance, method
      end
    end

    def initialize
      @strategies = {
        faraday: FaradayStrategy,
        botasaurus: BotasaurusStrategy,
        browserless: BrowserlessStrategy
      }
      @default_strategy_name = :faraday
    end

    # @return [Symbol] the default strategy name
    attr_reader :default_strategy_name

    ##
    # Sets the default strategy.
    # @param strategy [Symbol] the name of the strategy
    # @return [Symbol] the selected default strategy name
    # @raise [UnknownStrategy] if the strategy is not registered
    def default_strategy_name=(strategy)
      raise UnknownStrategy unless strategy_registered?(strategy)

      @default_strategy_name = strategy.to_sym
    end

    # @return [Array<String>] the names of the registered strategies
    def strategy_names = @strategies.keys.map(&:to_s)

    ##
    # Registers a new strategy.
    # @param name [Symbol] the name of the strategy
    # @param strategy_class [Class] the class implementing the strategy
    # @return [Class] the registered strategy class
    # @raise [ArgumentError] if strategy_class is not a Class
    def register_strategy(name, strategy_class)
      unless strategy_class.is_a?(Class)
        raise ArgumentError, "Expected a Class for strategy, got #{strategy_class.class}"
      end

      @strategies[name.to_sym] = strategy_class
    end

    ##
    # Checks if a strategy is registered.
    # @param name [Symbol] the name of the strategy
    # @return [Boolean] true if the strategy is registered, false otherwise.
    def strategy_registered?(name)
      @strategies.key?(name.to_sym)
    end

    ##
    # Unregisters a strategy.
    # @param name [Symbol] the name of the strategy
    # @return [Boolean] true if the strategy was unregistered, false otherwise.
    # @raise [ArgumentError] if attempting to unregister the default strategy.
    def unregister_strategy(name) # rubocop:disable Naming/PredicateMethod
      name_sym = name.to_sym
      raise ArgumentError, 'Cannot unregister the default strategy.' if name_sym == @default_strategy_name

      !!@strategies.delete(name_sym)
    end

    ##
    # Executes the request using the specified strategy.
    # @param ctx [Context] the context for the request.
    # @param strategy [Symbol] the strategy to use (defaults to the default strategy).
    # @return [Response] the response from the executed strategy.
    # @raise [ArgumentError] if the context is nil.
    # @raise [UnknownStrategy] if the strategy is not registered.
    def execute(ctx, strategy: default_strategy_name)
      strategy_class = @strategies.fetch(strategy.to_sym) do
        raise UnknownStrategy,
              "The strategy '#{strategy}' is not known. Available strategies: #{strategy_names.join(', ')}"
      end

      strategy_class.new(ctx).execute
    end
  end
end
