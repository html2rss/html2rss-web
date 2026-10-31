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
    module ErrorClassifier # rubocop:disable Metrics/ModuleLength -- Decision catalog + chain classify
      QUEUE_OR_BOOT_PHASES = Set['queue', 'boot'].freeze

      ##
      # Immutable HTTP decision for a classified error.
      Decision = Data.define(
        :status, :code, :message, :kind, :cacheable, :retryable, :next_action, :retry_action
      ) do
        # Maps <500 classified decisions to their empty RenderResult reason.
        #
        # @return [String]
        def empty_reason
          case code
          when BLOCKED_SURFACE_CODE then 'blocked_surface'
          when 'FORBIDDEN' then 'forbidden'
          when 'BAD_REQUEST' then 'invalid_input'
          else 'content_extraction_empty'
          end
        end
      end

      ##
      # Gem strategy attempts plus expanded transport telemetry for feed Observability / headers.
      TRANSPORT_KEYS = %i[request_id strategy_used render_ms error_category timeout_phase].freeze

      Diagnostics = Data.define(
        :strategy_attempts, :request_id, :strategy_used, :render_ms, :error_category, :timeout_phase,
        :surface_category
      ) do
        class << self
          # @return [Html2rss::Web::ErrorClassifier::Diagnostics]
          def empty
            EMPTY_DIAGNOSTICS
          end

          # Digs strategy attempts and surface_category from the exception cause chain.
          # Prefer +timeout_phase+ from transport_meta; else from +RequestTimedOut+ in the chain.
          # Carried {DecidedError} diagnostics win when non-empty.
          #
          # @param error [Exception, nil]
          # @return [Html2rss::Web::ErrorClassifier::Diagnostics]
          def from_error(error) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity -- chain dig
            carried = decided_diagnostics(error)
            return carried if carried

            chain = ErrorClassifier.error_chain(error)
            with_attempts = chain.find { it.is_a?(::Html2rss::Error) && Array(it.attempts).any? }
            meta_error = chain.find { it.is_a?(::Html2rss::Error) && it.transport_meta&.any? }
            list = with_attempts ? Array(with_attempts.attempts) : []
            fields = transport_fields(list, fallback_meta: meta_error&.transport_meta)
            fields[:timeout_phase] ||= timeout_phase_from_chain(chain)
            fields[:surface_category] = surface_category_from_chain(chain)

            return EMPTY_DIAGNOSTICS if list.empty? && fields.values.all?(&:nil?)

            new(strategy_attempts: list, **fields)
          end

          # Expands attempt hashes into transport fields (single dig algorithm).
          #
          # @param attempts [Array<Hash>, nil]
          # @return [Html2rss::Web::ErrorClassifier::Diagnostics]
          def from_attempts(attempts)
            list = Array(attempts)
            return EMPTY_DIAGNOSTICS if list.empty?

            new(strategy_attempts: list, surface_category: nil, **transport_fields(list))
          end

          private

          # @param error [Exception, nil]
          # @return [Html2rss::Web::ErrorClassifier::Diagnostics, nil]
          def decided_diagnostics(error)
            return unless error.is_a?(DecidedError)
            return if error.diagnostics == EMPTY_DIAGNOSTICS

            error.diagnostics
          end

          # @param attempts [Array<Hash>]
          # @param fallback_meta [Hash, nil]
          # @return [Hash{Symbol=>Object}]
          def transport_fields(attempts, fallback_meta: nil)
            meta = attempts.filter_map { it[:transport_meta] || it['transport_meta'] }.last || fallback_meta
            TRANSPORT_KEYS.to_h { [it, dig_meta(meta, it)] }
          end

          # @param chain [Array<Exception>]
          # @return [Object, nil]
          def timeout_phase_from_chain(chain)
            chain.find { it.is_a?(::Html2rss::RequestService::RequestTimedOut) }&.timeout_phase
          end

          # @param chain [Array<Exception>]
          # @return [Symbol, nil]
          def surface_category_from_chain(chain)
            chain.find { it.is_a?(::Html2rss::NoFeedItemsExtracted) }&.surface_category
          end

          # @param meta [Hash, nil]
          # @param key [Symbol]
          # @return [Object, nil]
          def dig_meta(meta, key)
            return unless meta

            meta[key] || meta[key.to_s]
          end
        end

        # Sparse hash for Observability emit (omits blank fields).
        #
        # @return [Hash{Symbol=>Object}]
        def to_h
          super.reject { |_, val| val.nil? || val == [] }
        end
      end
      EMPTY_DIAGNOSTICS = Diagnostics.new(
        strategy_attempts: [].freeze,
        request_id: nil,
        strategy_used: nil,
        render_ms: nil,
        error_category: nil,
        timeout_phase: nil,
        surface_category: nil
      ).freeze

      ##
      # Carries an already-computed {Decision} through raise → {ErrorResponder}.
      class DecidedError < StandardError
        # @return [Html2rss::Web::ErrorClassifier::Decision]
        attr_reader :decision
        # @return [Html2rss::Web::ErrorClassifier::Diagnostics]
        attr_reader :diagnostics

        # @param decision [Html2rss::Web::ErrorClassifier::Decision]
        # @param diagnostics [Html2rss::Web::ErrorClassifier::Diagnostics]
        def initialize(decision, diagnostics: Diagnostics.empty)
          @decision = decision
          @diagnostics = diagnostics
          super(decision.message)
        end
      end

      # Wall-clock / transport timeouts → {GATEWAY_TIMEOUT} (or capacity → {SERVICE_UNAVAILABLE}).
      TIMEOUT_ERRORS = [
        Timeout::Error, Errno::ETIMEDOUT, Async::TimeoutError, HTTPX::TimeoutError
      ].freeze

      # Non-timeout transport failures → internal network decision when unclassified.
      NETWORK_ERRORS = [
        SocketError, EOFError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
        HTTPX::ConnectionError, HTTPX::TLSError,
        *(if ::Html2rss::RequestService.const_defined?(:ConnectionFailed, false)
            [::Html2rss::RequestService::ConnectionFailed]
          else
            []
          end)
      ].freeze

      # Gem errors raised for invalid user-supplied values (config options, URLs).
      CLIENT_VALIDATION_ERRORS = [::Html2rss::InvalidOption, ::Html2rss::Url::InvalidUrlError].freeze

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
        cacheable: true,
        **INPUT_META
      ).freeze

      # Shell / high-entropy empties stay a plain 422 but must not be stored.
      EXTRACTION_EMPTY_UNCACHEABLE = EXTRACTION_EMPTY.with(cacheable: false).freeze

      # NoFeedItemsExtracted surfaces that stay EXTRACTION_EMPTY but must not be cached.
      SHELL_EMPTY_CATEGORIES = Set[:app_shell, :high_entropy_surface].freeze

      BLOCKED_SURFACE_CODE = 'BLOCKED_SURFACE'
      BLOCKED_SURFACE_MESSAGE = 'This site blocked automated access. Try another URL or site.'

      # Anti-bot challenge surfaces deterministically block automated fetches for this IP;
      # cacheable: true avoids hammering challenge endpoints during the feed TTL.
      BLOCKED_SURFACE = Decision.new(
        status: 422, code: BLOCKED_SURFACE_CODE, message: BLOCKED_SURFACE_MESSAGE,
        cacheable: true, **INPUT_META
      ).freeze

      SCRAPER_UNAVAILABLE_CODE = 'SCRAPER_UNAVAILABLE'
      SCRAPER_UNAVAILABLE_MESSAGE = 'Feed fetching is temporarily unavailable.'

      SCRAPER_UNAVAILABLE = Decision.new(
        status: 503,
        code: SCRAPER_UNAVAILABLE_CODE,
        message: SCRAPER_UNAVAILABLE_MESSAGE,
        kind: 'server',
        cacheable: false,
        **RETRY_META
      ).freeze

      SERVICE_UNAVAILABLE = Decision.new(
        status: 503,
        code: 'SERVICE_UNAVAILABLE',
        message: 'The server is too busy or the request timed out.',
        kind: 'server',
        cacheable: false,
        **RETRY_META
      ).freeze

      GATEWAY_TIMEOUT = Decision.new(
        status: 504,
        code: 'GATEWAY_TIMEOUT',
        message: 'The target website took too long to respond.',
        kind: 'network',
        cacheable: false,
        **RETRY_META
      ).freeze

      INTERNAL_SERVER_ERROR = Decision.new(
        status: 500,
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Internal Server Error',
        kind: 'server',
        cacheable: false,
        **RETRY_META
      ).freeze

      PRIVATE_NETWORK_DENIED = Decision.new(
        status: 403,
        code: 'FORBIDDEN',
        message: 'Requests to private or loopback networks are forbidden.',
        cacheable: true,
        **INPUT_META
      ).freeze

      INTERNAL_NETWORK_ERROR = Decision.new(
        status: 500,
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Internal Server Error',
        kind: 'network',
        cacheable: false,
        **RETRY_META
      ).freeze

      class << self
        # Returns an immutable HTTP decision for any error.
        #
        # @param error [Exception]
        # @return [Html2rss::Web::ErrorClassifier::Decision]
        def classify(error)
          return error.decision if error.is_a?(DecidedError)

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
            current = current.cause
          end

          chain
        end

        private

        def classify_http_error(error)
          case error
          when TooManyRequestsError
            decision_for_http_error(error, RETRY_META.merge(kind: 'client'),
                                    default_message: 'Too many requests. Wait before retrying.')
          when UnauthorizedError then decision_for_http_error(error, AUTH_META)
          when BadRequestError, ForbiddenError then decision_for_http_error(error, INPUT_META)
          when HealthCheckFailedError then decision_for_http_error(error, SERVER_META)
          when HttpError then decision_for_http_error(error, RETRY_META.merge(kind: error_kind_for(error)))
          end
        end

        # @param error [Exception]
        # @return [Html2rss::Web::ErrorClassifier::Decision, nil]
        def classify_special_error(error)
          chain = error_chain(error)
          no_items = chain.find { it.is_a?(::Html2rss::NoFeedItemsExtracted) }
          return empty_items_decision(no_items) if no_items
          return BLOCKED_SURFACE if chain.any?(::Html2rss::RequestService::BlockedSurfaceDetected)
          return SCRAPER_UNAVAILABLE if chain.any?(::Html2rss::RequestService::BotasaurusConnectionFailed)
          return PRIVATE_NETWORK_DENIED if chain.any?(::Html2rss::RequestService::PrivateNetworkDenied)

          client_validation_decision(chain) || timeout_decision(chain)
        end

        # Gem rejections of caller-supplied values pass the gem message through as a 400.
        #
        # @param chain [Array<Exception>]
        # @return [Html2rss::Web::ErrorClassifier::Decision, nil]
        def client_validation_decision(chain)
          invalid = chain.find { |err| CLIENT_VALIDATION_ERRORS.any? { |klass| err.is_a?(klass) } }
          return unless invalid

          Decision.new(status: 400, code: 'BAD_REQUEST', message: invalid.message, cacheable: false, **INPUT_META)
        end

        # @param no_items [Html2rss::NoFeedItemsExtracted]
        # @return [Html2rss::Web::ErrorClassifier::Decision]
        def empty_items_decision(no_items)
          case no_items.surface_category
          when :blocked_surface then BLOCKED_SURFACE
          when *SHELL_EMPTY_CATEGORIES then EXTRACTION_EMPTY_UNCACHEABLE
          else EXTRACTION_EMPTY
          end
        end

        # @param chain [Array<Exception>]
        # @return [Html2rss::Web::ErrorClassifier::Decision, nil]
        def timeout_decision(chain)
          timed_out = chain.find { it.is_a?(::Html2rss::RequestService::RequestTimedOut) }
          return SERVICE_UNAVAILABLE if timed_out && QUEUE_OR_BOOT_PHASES.include?(timed_out.timeout_phase)
          return GATEWAY_TIMEOUT if timed_out || chain.any? { timeout_error?(it) }

          nil
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
          error_chain(error).any? { network_error_class?(it) }
        end

        def network_error_class?(err)
          timeout_error?(err) || NETWORK_ERRORS.any? { err.is_a?(it) }
        end

        def timeout_error?(err)
          TIMEOUT_ERRORS.any? { err.is_a?(it) }
        end
      end
    end
  end
end
