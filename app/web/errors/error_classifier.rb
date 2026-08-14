# frozen_string_literal: true

require 'timeout'

module Html2rss
  module Web
    ##
    # Classifies exception chains into immutable HTTP error decisions and telemetry diagnostics.
    #
    # Acts as the single source of truth for error-to-HTTP mapping across both
    # XML feed and JSON API endpoints.
    module ErrorClassifier # rubocop:disable Metrics/ModuleLength
      ##
      # Immutable HTTP decision for a classified error.
      Decision = Data.define(
        :status, :code, :message, :kind, :cacheable, :retryable, :next_action, :retry_action
      )

      NETWORK_ERRORS = Set[
        Timeout::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError,
        EOFError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
      ].freeze

      AUTH_META = { kind: 'auth', retryable: false, next_action: 'enter_token', retry_action: 'none' }.freeze
      INPUT_META = { kind: 'input', retryable: false, next_action: 'correct_input', retry_action: 'none' }.freeze
      SERVER_META = { kind: 'server', retryable: false, next_action: 'none', retry_action: 'none' }.freeze
      RETRY_META = { retryable: true, next_action: 'retry', retry_action: 'primary' }.freeze

      EXTRACTION_EMPTY_CODE = 'EXTRACTION_EMPTY'
      EXTRACTION_EMPTY_MESSAGE = 'We could not extract feed items from this page yet. ' \
                                 'Try a more specific listing URL or explicit selectors.'

      EXTRACTION_EMPTY = Decision.new(
        status: 422,
        code: EXTRACTION_EMPTY_CODE,
        message: EXTRACTION_EMPTY_MESSAGE,
        kind: 'input',
        cacheable: true,
        retryable: false,
        next_action: 'correct_input',
        retry_action: 'none'
      ).freeze

      BLOCKED_SURFACE_CODE = 'BLOCKED_SURFACE'
      BLOCKED_SURFACE_MESSAGE = 'The target website is protected by an anti-bot challenge or Cloudflare block.'

      BLOCKED_SURFACE = Decision.new(
        status: 422,
        code: BLOCKED_SURFACE_CODE,
        message: BLOCKED_SURFACE_MESSAGE,
        kind: 'input',
        cacheable: true,
        retryable: false,
        next_action: 'correct_input',
        retry_action: 'none'
      ).freeze

      SCRAPER_UNAVAILABLE_CODE = 'SCRAPER_UNAVAILABLE'
      SCRAPER_UNAVAILABLE_MESSAGE = 'The scraping backend is temporarily unavailable. Please try again later.'

      SCRAPER_UNAVAILABLE = Decision.new(
        status: 503,
        code: SCRAPER_UNAVAILABLE_CODE,
        message: SCRAPER_UNAVAILABLE_MESSAGE,
        kind: 'server',
        cacheable: false,
        retryable: true,
        next_action: 'retry',
        retry_action: 'primary'
      ).freeze

      SERVICE_UNAVAILABLE = Decision.new(
        status: 503,
        code: 'SERVICE_UNAVAILABLE',
        message: 'The server is too busy or the request timed out. Please try again later.',
        kind: 'server',
        cacheable: false,
        retryable: true,
        next_action: 'retry',
        retry_action: 'primary'
      ).freeze

      GATEWAY_TIMEOUT = Decision.new(
        status: 504,
        code: 'GATEWAY_TIMEOUT',
        message: 'The target website took too long to respond. Please try again later.',
        kind: 'network',
        cacheable: false,
        retryable: true,
        next_action: 'retry',
        retry_action: 'primary'
      ).freeze

      INTERNAL_SERVER_ERROR = Decision.new(
        status: 500,
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Internal Server Error',
        kind: 'server',
        cacheable: false,
        retryable: true,
        next_action: 'retry',
        retry_action: 'primary'
      ).freeze

      INTERNAL_NETWORK_ERROR = Decision.new(
        status: 500,
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Internal Server Error',
        kind: 'network',
        cacheable: false,
        retryable: true,
        next_action: 'retry',
        retry_action: 'primary'
      ).freeze

      SPECIAL_DECISIONS = [
        [lambda { |c, _|
           defined?(::Html2rss::NoFeedItemsExtracted) && c.any?(::Html2rss::NoFeedItemsExtracted)
         }, EXTRACTION_EMPTY],
        [lambda { |c, _|
           defined?(::Html2rss::RequestService::BlockedSurfaceDetected) &&
             c.any?(::Html2rss::RequestService::BlockedSurfaceDetected)
         }, BLOCKED_SURFACE],
        [lambda { |c, _|
           (defined?(::Html2rss::RequestService::BotasaurusConnectionFailed) &&
             c.any?(::Html2rss::RequestService::BotasaurusConnectionFailed)) ||
             (defined?(::Html2rss::RequestService::BrowserlessConnectionFailed) &&
               c.any?(::Html2rss::RequestService::BrowserlessConnectionFailed))
         }, SCRAPER_UNAVAILABLE],
        [lambda { |_, err|
           defined?(::Rack::Timeout::RequestTimeoutException) && err.is_a?(::Rack::Timeout::RequestTimeoutException)
         }, SERVICE_UNAVAILABLE],
        [->(_, err) { err.is_a?(Timeout::Error) || err.is_a?(Errno::ETIMEDOUT) }, GATEWAY_TIMEOUT]
      ].freeze

      class << self
        # Returns an immutable HTTP decision for any error.
        #
        # @param error [Exception]
        # @return [Html2rss::Web::ErrorClassifier::Decision]
        def classify(error)
          classify_special_error(error) || classify_http_error(error) || classify_unhandled_error(error)
        end

        # Walks +Exception#cause+ without following identity cycles.
        #
        # @param error [Exception, nil]
        # @return [Array<Exception>]
        def error_chain(error)
          chain = []
          seen = {}.compare_by_identity
          current = error

          while current && !seen[current]
            chain << current
            seen[current] = true
            current = current.respond_to?(:cause) ? current.cause : nil
          end

          chain
        end

        # Extracts upstream scraper attempts and transport telemetry from the exception chain.
        #
        # @param error [Exception, nil]
        # @return [Hash{Symbol=>Object}]
        def extract_diagnostics(error)
          chain = error_chain(error)
          with_attempts = chain.find { it.respond_to?(:attempts) }
          attempts = with_attempts ? Array(with_attempts.attempts) : []
          meta = attempts.filter_map { it[:transport_meta] || it['transport_meta'] }.last
          return attempts.empty? ? {} : { strategy_attempts: attempts } unless meta

          diagnostics = attempts.empty? ? {} : { strategy_attempts: attempts }
          append_meta_fields(diagnostics, meta)
        end

        private

        def classify_http_error(error)
          case error
          when TooManyRequestsError
            decision_for_http_error(error, RETRY_META.merge(kind: 'client'),
                                    default_message: 'Too many requests. Please wait before retrying.')
          when UnauthorizedError then decision_for_http_error(error, AUTH_META)
          when BadRequestError, ForbiddenError then decision_for_http_error(error, INPUT_META)
          when HealthCheckFailedError then decision_for_http_error(error, SERVER_META)
          when HttpError then decision_for_http_error(error, RETRY_META.merge(kind: error_kind_for(error)))
          end
        end

        def classify_special_error(error)
          chain = error_chain(error)
          SPECIAL_DECISIONS.find { |match, _| match.call(chain, error) }&.last
        end

        def append_meta_fields(diagnostics, meta)
          %i[request_id strategy_used render_ms error_category].each do |key|
            val = meta[key] || meta[key.to_s]
            diagnostics[key] = val if val
          end
          diagnostics
        end

        def error_kind_for(error)
          return 'client' if error.status == 429

          network_error?(error) ? 'network' : 'server'
        end

        def classify_unhandled_error(error)
          network_error?(error) ? INTERNAL_NETWORK_ERROR : INTERNAL_SERVER_ERROR
        end

        def decision_for_http_error(error, meta, default_message: nil)
          message = if error.message != error.class.name && !error.message.to_s.empty?
                      error.message
                    else
                      default_message || error.class::DEFAULT_MESSAGE
                    end

          Decision.new(status: error.status, code: error.code, message:, cacheable: false, **meta)
        end

        def network_error?(error)
          error_chain(error).any? { NETWORK_ERRORS.include?(it.class) }
        end
      end
    end
  end
end
