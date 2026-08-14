# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Classifies known exception chains into immutable HTTP error decisions.
    #
    # Ownership of +Exception#cause+ walking lives here so feed rendering and
    # HTTP responders share one extraction-empty mapping.
    module ErrorClassifier
      ##
      # Immutable HTTP decision for a classified error.
      Decision = Data.define(
        :status, :code, :message, :kind, :cacheable, :retryable, :next_action, :retry_action
      )

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

      class << self
        # Returns a decision when +error+ (or a cause) is a known classified
        # failure. Ignores gem-specific payload fields such as +attempts+.
        #
        # @param error [Exception]
        # @return [Html2rss::Web::ErrorClassifier::Decision, nil]
        def classify(error)
          return EXTRACTION_EMPTY if extraction_empty?(error)
          return BLOCKED_SURFACE if blocked_surface?(error)
          return SCRAPER_UNAVAILABLE if scraper_unavailable?(error)

          nil
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

        private

        # @param error [Exception]
        # @return [Boolean]
        def extraction_empty?(error)
          return false unless defined?(::Html2rss::NoFeedItemsExtracted)

          error_chain(error).any?(::Html2rss::NoFeedItemsExtracted)
        end

        # @param error [Exception]
        # @return [Boolean]
        def blocked_surface?(error)
          return false unless defined?(::Html2rss::RequestService::BlockedSurfaceDetected)

          error_chain(error).any?(::Html2rss::RequestService::BlockedSurfaceDetected)
        end

        # @param error [Exception]
        # @return [Boolean]
        def scraper_unavailable?(error)
          chain = error_chain(error)
          if defined?(::Html2rss::RequestService::BotasaurusConnectionFailed) &&
             chain.any?(::Html2rss::RequestService::BotasaurusConnectionFailed)
            return true
          end
          if defined?(::Html2rss::RequestService::BrowserlessConnectionFailed) &&
             chain.any?(::Html2rss::RequestService::BrowserlessConnectionFailed)
            return true
          end

          false
        end
      end
    end
  end
end
