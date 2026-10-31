# frozen_string_literal: true

require 'timeout'
require 'net/http'
require 'async'
require 'httpx'

module Html2rss
  module Web
    ##
    # Classifies exception chains into immutable HTTP error decisions and telemetry diagnostics.
    #
    # Acts as the single source of truth for error-to-HTTP mapping across both
    # XML feed and JSON API endpoints.
    module ErrorClassifier
      QUEUE_OR_BOOT_PHASES = Set['queue', 'boot'].freeze

      # Wall-clock / transport timeouts become {GATEWAY_TIMEOUT} (or capacity {SERVICE_UNAVAILABLE}).
      TIMEOUT_ERRORS = [
        Timeout::Error, Errno::ETIMEDOUT, Async::TimeoutError, HTTPX::TimeoutError
      ].freeze

      # Non-timeout transport failures become an internal network decision when unclassified.
      NETWORK_ERRORS = [
        SocketError, EOFError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
        HTTPX::ConnectionError, HTTPX::TLSError,
        ::Html2rss::RequestService::ConnectionFailed
      ].freeze

      # Gem errors raised for invalid user-supplied values (config options, URLs).
      CLIENT_VALIDATION_ERRORS = [::Html2rss::InvalidOption, ::Html2rss::Url::InvalidUrlError].freeze

      AUTH_META = { kind: 'auth', retryable: false, next_action: 'enter_token', retry_action: 'none' }.freeze
      INPUT_META = { kind: 'input', retryable: false, next_action: 'correct_input', retry_action: 'none' }.freeze
      RETRY_META = { retryable: true, next_action: 'retry', retry_action: 'primary' }.freeze

      EXTRACTION_EMPTY_CODE = 'EXTRACTION_EMPTY'
      EXTRACTION_EMPTY_MESSAGE = 'We could not extract feed items from this page yet. ' \
                                 'Try a more specific listing URL or explicit selectors.'
      EXTRACTION_EMPTY = Decision.of(422, EXTRACTION_EMPTY_CODE, EXTRACTION_EMPTY_MESSAGE,
                                     cacheable: true, **INPUT_META)

      # Shell / high-entropy empties stay a plain 422 but must not be stored.
      EXTRACTION_EMPTY_UNCACHEABLE = EXTRACTION_EMPTY.with(cacheable: false)

      # NoFeedItemsExtracted surfaces that stay EXTRACTION_EMPTY but must not be cached.
      SHELL_EMPTY_CATEGORIES = Set[:app_shell, :high_entropy_surface].freeze

      BLOCKED_SURFACE_CODE = 'BLOCKED_SURFACE'
      BLOCKED_SURFACE_MESSAGE = 'This site blocked automated access. Try another URL or site.'

      # Anti-bot challenge surfaces deterministically block automated fetches for this IP;
      # cacheable: true avoids hammering challenge endpoints during the feed TTL.
      BLOCKED_SURFACE = Decision.of(422, BLOCKED_SURFACE_CODE, BLOCKED_SURFACE_MESSAGE, cacheable: true, **INPUT_META)

      SCRAPER_UNAVAILABLE = Decision.of(503, 'SCRAPER_UNAVAILABLE', 'Feed fetching is temporarily unavailable.',
                                        kind: 'server', **RETRY_META)

      SERVICE_UNAVAILABLE = Decision.of(503, 'SERVICE_UNAVAILABLE', 'The server is too busy or the request timed out.',
                                        kind: 'server', **RETRY_META)

      GATEWAY_TIMEOUT = Decision.of(504, 'GATEWAY_TIMEOUT', 'The target website took too long to respond.',
                                    kind: 'network', **RETRY_META)

      INTERNAL_SERVER_ERROR = Decision.of(500, 'INTERNAL_SERVER_ERROR', 'Internal Server Error',
                                          kind: 'server', **RETRY_META)

      INTERNAL_NETWORK_ERROR = INTERNAL_SERVER_ERROR.with(kind: 'network')

      PRIVATE_NETWORK_DENIED = Decision.of(403, 'FORBIDDEN', 'Requests to private or loopback networks are forbidden.',
                                           cacheable: true, **INPUT_META)

      class << self
        # Returns an immutable HTTP decision for any error.
        #
        # @param error [Exception]
        # @return [Decision]
        def classify(error)
          return error.decision if error.is_a?(DecidedError)

          classify_special_error(error) || classify_http_error(error) || classify_unhandled_error(error)
        end

        # Walks +Exception#cause+ without following identity cycles.
        #
        # @param error [Exception, nil]
        # @return [Array<Exception>]
        def error_chain(error)
          seen = {}.compare_by_identity
          chain = []
          while error && !seen[error]
            chain << error
            seen[error] = true
            error = error.cause
          end
          chain
        end

        private

        # @param error [Exception]
        # @return [Decision, nil]
        def classify_http_error(error)
          case error
          in TooManyRequestsError then http_decision(error, RETRY_META.merge(kind: 'client'))
          in UnauthorizedError then http_decision(error, AUTH_META)
          in BadRequestError | ForbiddenError then http_decision(error, INPUT_META)
          in HealthCheckFailedError then http_decision(error, INPUT_META.merge(kind: 'server', next_action: 'none'))
          in HttpError then http_decision(error, RETRY_META.merge(kind: network_error?(error) ? 'network' : 'server'))
          else nil
          end
        end

        # @param error [Exception]
        # @return [Decision, nil]
        def classify_special_error(error)
          chain = error_chain(error)
          if (no_items = chain.find { it.is_a?(::Html2rss::NoFeedItemsExtracted) })
            return empty_items_decision(no_items)
          end
          return BLOCKED_SURFACE if chain.any?(::Html2rss::RequestService::BlockedSurfaceDetected)
          return SCRAPER_UNAVAILABLE if chain.any?(::Html2rss::RequestService::BotasaurusConnectionFailed)
          return PRIVATE_NETWORK_DENIED if chain.any?(::Html2rss::RequestService::PrivateNetworkDenied)

          client_validation_decision(chain) || timeout_decision(chain)
        end

        # Gem rejections of caller-supplied values pass the gem message through as a 400.
        #
        # @param chain [Array<Exception>]
        # @return [Decision, nil]
        def client_validation_decision(chain)
          invalid = chain.find { |err| kind_of_any?(err, CLIENT_VALIDATION_ERRORS) }
          Decision.of(400, 'BAD_REQUEST', invalid.message, **INPUT_META) if invalid
        end

        # @param no_items [Html2rss::NoFeedItemsExtracted]
        # @return [Decision]
        def empty_items_decision(no_items)
          case no_items.surface_category
          when :blocked_surface then BLOCKED_SURFACE
          when *SHELL_EMPTY_CATEGORIES then EXTRACTION_EMPTY_UNCACHEABLE
          else EXTRACTION_EMPTY
          end
        end

        # @param chain [Array<Exception>]
        # @return [Decision, nil]
        def timeout_decision(chain)
          timed_out = chain.find { it.is_a?(::Html2rss::RequestService::RequestTimedOut) }
          return SERVICE_UNAVAILABLE if timed_out && QUEUE_OR_BOOT_PHASES.include?(timed_out.timeout_phase)

          GATEWAY_TIMEOUT if timed_out || chain.any? { kind_of_any?(it, TIMEOUT_ERRORS) }
        end

        # @param error [Exception]
        # @return [Decision]
        def classify_unhandled_error(error) = network_error?(error) ? INTERNAL_NETWORK_ERROR : INTERNAL_SERVER_ERROR

        # @param error [HttpError]
        # @param meta [Hash{Symbol=>Object}]
        # @return [Decision]
        def http_decision(error, meta)
          message = error.message
          message = error.class::DEFAULT_MESSAGE if message.empty? || message == error.class.name
          Decision.of(error.status, error.code, message, **meta)
        end

        # @param error [Exception]
        # @return [Boolean]
        def network_error?(error)
          error_chain(error).any? { kind_of_any?(it, TIMEOUT_ERRORS) || kind_of_any?(it, NETWORK_ERRORS) }
        end

        # @param error [Exception]
        # @param classes [Array<Class>]
        # @return [Boolean]
        def kind_of_any?(error, classes) = classes.any? { error.is_a?(it) }
      end
    end
  end
end
