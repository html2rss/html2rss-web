# frozen_string_literal: true

require 'json'

module Html2rss
  module Web
    ##
    # Gate for client-authored selectors before they are signed into, or read back from, a feed token.
    #
    # Only the selectors subtree is ever accepted; channel, headers and strategy stay server-owned.
    # {.parse} runs on create and again after the token signature verified, so a leaked signing
    # secret cannot widen what a token may execute.
    module SelectorsDocument
      ##
      # Raised when selectors fail gem schema validation. Carries the report so callers
      # can render issues without re-validating.
      class SchemaInvalid < BadRequestError
        # @return [Html2rss::Config::ValidationReport]
        attr_reader :report

        # @param report [Html2rss::Config::ValidationReport]
        def initialize(report)
          @report = report
          super(report.to_s)
        end
      end

      # Keeps the signed token inside practical feed-URL lengths.
      MAX_BYTES = 2_048
      # Placeholder channel so schema validation can judge the selectors subtree alone.
      VALIDATION_CHANNEL_URL = 'https://example.com/'
      private_constant :VALIDATION_CHANNEL_URL

      class << self
        ##
        # @param raw [Object] client or decoded-token selectors; nil or empty means none
        # @return [Hash{Symbol=>Object}, nil] validated selectors, nil when absent
        # @raise [Html2rss::Web::BadRequestError] when not an object, too large, or schema-invalid
        def parse(raw)
          return if raw.nil? || raw == {}
          raise BadRequestError, 'selectors must be an object' unless raw.is_a?(Hash)

          selectors = Html2rss::HashUtil.deep_symbolize_keys(raw, context: 'selectors')
          enforce_size!(selectors)
          validate!(selectors)
          selectors
        end

        private

        # @param selectors [Hash{Symbol=>Object}]
        # @return [void]
        def enforce_size!(selectors)
          return if JSON.generate(selectors).bytesize <= MAX_BYTES

          raise BadRequestError, "selectors exceed #{MAX_BYTES} bytes"
        end

        # @param selectors [Hash{Symbol=>Object}]
        # @return [void]
        # @raise [SchemaInvalid]
        def validate!(selectors)
          report = Html2rss::Config.validate({ channel: { url: VALIDATION_CHANNEL_URL }, selectors: })
          raise SchemaInvalid, report unless report.success?
        end
      end
    end
  end
end
