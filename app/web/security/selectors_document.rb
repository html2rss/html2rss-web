# frozen_string_literal: true

require 'json'

module Html2rss
  module Web
    ##
    # Client-authored selectors subtree after the root key gate and gem schema
    # validation. May be signed into a feed token.
    #
    # This is the only owner of which config root keys may be client-authored.
    # {.from_client} and {.from_wire} share one rule so a leaked signing
    # secret cannot widen what decode will execute.
    SelectorsDocument = Data.define(:selectors) do
      ##
      # @param selectors [Hash{Symbol=>Object}] selectors subtree
      # @return [Html2rss::Web::SelectorsDocument]
      def initialize(selectors:)
        super(selectors: deep_freeze(selectors))
      end

      ##
      # Fragment merged into the token generator config. Never includes channel,
      # headers, or any other client-controlled root key.
      #
      # @return [Hash{Symbol=>Object}]
      def to_config_fragment = { selectors: }.freeze

      ##
      # Wire document stored under the token +c:+ key and covered by the signature.
      #
      # @return [Hash{Symbol=>Object}]
      def to_wire = to_config_fragment

      ##
      # @return [Boolean]
      def empty? = selectors.empty?

      private

      # @param value [Object]
      # @return [Object]
      def deep_freeze(value)
        case value
        in Hash then value.each_value { deep_freeze(it) }
        in Array then value.each { deep_freeze(it) }
        # HashUtil reuses string references; dup so freezing the handoff cannot
        # freeze the caller's mutable strings.
        in String then return value.dup.freeze
        else return value
        end
        value.freeze
      end
    end

    class SelectorsDocument
      ##
      # Raised when a fragment clears the root key gate but fails gem schema validation.
      #
      # Carries the report so callers can render issues without re-validating or
      # inspecting the exception message.
      class SchemaInvalid < BadRequestError
        # @return [Html2rss::Config::ValidationReport]
        attr_reader :report

        # @param report [Html2rss::Config::ValidationReport]
        def initialize(report)
          @report = report
          super(report.to_s)
        end
      end

      # Root keys a client fragment may contain. Published schema reads this set.
      CLIENT_ROOT_KEYS = Set[:selectors].freeze
      # Root keys rejected by name so the error is not a generic invalid-config.
      DENIED_ROOT_KEYS = Set[
        :auto_source, :channel, :directory, :headers, :params, :registry, :request, :strategy, :stylesheets
      ].freeze
      # Keeps the signed token inside practical feed-URL lengths.
      MAX_WIRE_BYTES = 2_048
      # Placeholder channel used only so schema validation can judge the selectors subtree.
      VALIDATION_CHANNEL_URL = 'https://example.com/'
      private_constant :VALIDATION_CHANNEL_URL

      class << self
        ##
        # Builds a selectors document from a client config fragment.
        #
        # @param hash [Hash] client object; only +selectors+ is permitted
        # @return [Html2rss::Web::SelectorsDocument]
        # @raise [Html2rss::Web::BadRequestError] when the fragment fails the root key gate
        def from_client(hash) = build(hash, validate_shape: true)

        ##
        # Rebuilds a selectors document from a decoded but *unverified* token wire document.
        #
        # Runs the structural root key gate only. Schema validation is withheld until the
        # HMAC has been checked, so an unauthenticated caller cannot drive the gem
        # validator with an unsigned token. {.from_verified_wire} runs it afterwards.
        #
        # @param hash [Hash] wire object previously returned by {#to_wire}
        # @return [Html2rss::Web::SelectorsDocument]
        # @raise [Html2rss::Web::BadRequestError] when the fragment fails the root key gate
        def from_wire(hash) = build(hash, validate_shape: false)

        ##
        # Rebuilds a selectors document from a wire document whose signature already verified.
        #
        # @param hash [Hash] wire object previously returned by {#to_wire}
        # @return [Html2rss::Web::SelectorsDocument]
        # @raise [Html2rss::Web::BadRequestError] when the fragment fails the root key gate
        def from_verified_wire(hash) = build(hash, validate_shape: true)

        private

        # @param hash [Object]
        # @param validate_shape [Boolean]
        # @return [Html2rss::Web::SelectorsDocument]
        def build(hash, validate_shape:)
          selectors = permitted_selectors(normalized_fragment(hash))
          enforce_wire_limit!(selectors)
          validate_shape!(selectors) if validate_shape
          new(selectors:)
        end

        # @param hash [Object]
        # @return [Hash{Symbol=>Object}]
        def normalized_fragment(hash)
          raise BadRequestError, 'selectors document must be an object' unless hash.is_a?(Hash)

          Html2rss::HashUtil.deep_symbolize_keys(hash, context: 'selectors document')
        end

        # @param fragment [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def permitted_selectors(fragment)
          reject_keys!(fragment)
          selectors = fragment[:selectors]
          raise BadRequestError, 'selectors must be an object' unless selectors.is_a?(Hash)

          selectors
        end

        # @param fragment [Hash{Symbol=>Object}]
        # @return [void]
        def reject_keys!(fragment)
          denied = fragment.each_key.find { DENIED_ROOT_KEYS.include?(it) }
          raise BadRequestError, "#{denied} is not allowed" if denied

          unknown = fragment.each_key.find { !CLIENT_ROOT_KEYS.include?(it) }
          raise BadRequestError, "#{unknown} is not allowed" if unknown
        end

        # @param selectors [Hash{Symbol=>Object}]
        # @return [void]
        def enforce_wire_limit!(selectors)
          return if JSON.generate({ selectors: }).bytesize <= MAX_WIRE_BYTES

          raise BadRequestError, "selectors document exceeds #{MAX_WIRE_BYTES} bytes"
        end

        # @param selectors [Hash{Symbol=>Object}]
        # @return [void]
        # @raise [Html2rss::Web::SelectorsDocument::SchemaInvalid]
        def validate_shape!(selectors)
          report = Html2rss::Config.validate({ channel: { url: VALIDATION_CHANNEL_URL }, selectors: })
          return if report.success?

          raise SchemaInvalid, report
        end
      end
    end
  end
end
