# frozen_string_literal: true

##
# The Html2rss namespace.
module Html2rss
  ##
  # Coordinates feed generation pipeline stages.
  class FeedPipeline
    # Retries feed extraction across concrete request strategies for :auto mode.
    class AutoFallback
      # Ordered list of concrete request strategies attempted by auto mode.
      CHAIN = %i[faraday botasaurus browserless].freeze

      # Error classes that should abort auto fallback immediately.
      NON_FALLBACK_ERRORS = [
        RequestService::UnknownStrategy,
        RequestService::InvalidUrl,
        RequestService::UnsupportedUrlScheme,
        RequestService::UnsupportedResponseContentType,
        RequestService::RequestBudgetExceeded,
        RequestService::PrivateNetworkDenied,
        RequestService::CrossOriginFollowUpDenied,
        RequestService::ResponseTooLarge,
        RequestService::BrowserlessConfigurationError
      ].freeze

      ##
      # @param strategies [Array<Symbol>] ordered concrete strategies for fallback
      # @param budget [RequestService::Budget] shared request budget across retries
      # @param session_for [Proc] request session factory proc
      # @param articles_for [Proc] article extraction proc
      # @return [void]
      def initialize(strategies:, budget:, session_for:, articles_for:)
        @strategies = strategies
        @budget = budget
        @session_for = session_for
        @articles_for = articles_for
      end

      ##
      # @return [Hash{Symbol => Object}] pipeline state containing :response and :articles
      def call
        state, attempts = run_attempts
        return state if state

        finalize_failure(attempts:)
      end

      private

      attr_reader :strategies, :budget, :session_for, :articles_for

      def run_attempts
        state = { result: nil, attempts: [] }
        strategies.each_with_index do |strategy, index|
          run_attempt_for(strategy:, next_strategy: strategies[index + 1], state:)
          break if state.fetch(:result)
        end
        [state.fetch(:result), state.fetch(:attempts)]
      end

      def run_attempt_for(strategy:, next_strategy:, state:)
        result, attempts = attempt(
          strategy:,
          next_strategy:,
          state: { attempts: state.fetch(:attempts) }
        )
        state[:result] = result
        state[:attempts] = attempts
      end

      def attempt(strategy:, next_strategy:, state:)
        request_session = session_for.call(strategy:, budget:)
        response, state = fetch_response(
          request_session:,
          strategy:,
          next_strategy:,
          state:
        )
        return [nil, state.fetch(:attempts)] unless response

        process_response(response:, strategy:, next_strategy:, request_session:, state:)
      end

      def fetch_response(request_session:, strategy:, next_strategy:, state:)
        [request_session.fetch_initial_response, state]
      rescue *NON_FALLBACK_ERRORS
        raise
      rescue StandardError => error
        state[:attempts] << { strategy:, items_count: nil, error_class: error.class.name }
        log_warn_fallback_error(strategy:, next_strategy:, error:) if next_strategy
        Log.debug("#{self.class}: strategy=#{strategy} error=#{error.class}: #{error.message}")
        [nil, state]
      end

      def process_response(response:, strategy:, next_strategy:, request_session:, state:)
        articles = articles_for.call(response:, request_session:)
        items_count = articles.size
        state[:attempts] << { strategy:, items_count:, error_class: nil }
        Log.debug("#{self.class}: strategy=#{strategy} items=#{items_count}")
        return success_state(response:, strategy:, articles:, state:) if items_count.positive?

        log_info_fallback_zero_items(strategy:, next_strategy:) if next_strategy
        [nil, state.fetch(:attempts)]
      end

      def success_state(response:, strategy:, articles:, state:)
        if state.fetch(:attempts).size > 1
          Log.info("#{self.class}: auto selected strategy=#{strategy} after attempts=#{state.fetch(:attempts).size}")
        end
        [{ response:, articles: }, state.fetch(:attempts)]
      end

      def finalize_failure(attempts:)
        raise NoFeedItemsExtracted.new(attempts:)
      end

      def log_warn_fallback_error(strategy:, next_strategy:, error:)
        Log.warn("#{self.class}: auto fallback #{strategy} -> #{next_strategy} after error=#{error.class}")
      end

      def log_info_fallback_zero_items(strategy:, next_strategy:)
        Log.info("#{self.class}: auto fallback #{strategy} -> #{next_strategy} after zero extracted items")
      end
    end
  end
end
