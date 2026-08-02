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
      Decision = Data.define(:status, :code, :message, :kind, :cacheable)

      EXTRACTION_EMPTY_CODE = 'EXTRACTION_EMPTY'
      EXTRACTION_EMPTY_MESSAGE = 'We could not extract feed items from this page yet. ' \
                                 'Try a more specific listing URL or explicit selectors.'

      EXTRACTION_EMPTY = Decision.new(
        status: 422,
        code: EXTRACTION_EMPTY_CODE,
        message: EXTRACTION_EMPTY_MESSAGE,
        kind: 'input',
        cacheable: true
      ).freeze

      class << self
        # Returns a decision when +error+ (or a cause) is a known classified
        # failure. Ignores gem-specific payload fields such as +attempts+.
        #
        # @param error [Exception]
        # @return [Html2rss::Web::ErrorClassifier::Decision, nil]
        def classify(error)
          return EXTRACTION_EMPTY if extraction_empty?(error)

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
      end
    end
  end
end
