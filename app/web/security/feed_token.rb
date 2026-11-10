# frozen_string_literal: true

require 'base64'
require 'json'
require 'zlib'
require 'openssl'

module Html2rss
  module Web
    ##
    # Immutable feed-token value object.
    #
    # Wire encoding and signature verification are unified inside this class to
    # keep the token lifetime concerns cohesive.
    FeedToken = Data.define(:username, :url, :expires_at, :signature, :strategy, :selectors) do
      # @param selectors [Hash{Symbol=>Object}, nil] client-authored selectors covered by the signature
      def initialize(selectors: nil, **) = super

      # @return [Boolean]
      def expired?
        Time.now.to_i > expires_at
      end

      # @param candidate_url [String]
      # @return [Boolean]
      def valid_for_url?(candidate_url)
        url == candidate_url
      end
    end

    class FeedToken
      DEFAULT_EXPIRY = 315_360_000
      # Largest encoded token accepted from the wire; a token with maximal selectors stays well under it.
      MAX_ENCODED_BYTES = 4_096
      # Cap on the inflated wire document so a small unauthenticated token cannot force a large allocation.
      MAX_INFLATED_BYTES = 16_384

      class << self
        # @param username [String]
        # @param url [String]
        # @param strategy [String, nil]
        # @param selectors [Hash{Symbol=>Object}, nil] validated via {SelectorsDocument.parse}
        # @param expires_in [Integer] seconds (default: 10 years)
        # @return [String, nil] encoded signed token when inputs are valid.
        def generate(username, url, strategy: nil, selectors: nil, expires_in: DEFAULT_EXPIRY)
          token = Signer.create(username:, url:, strategy:, selectors:, expires_in:,
                                secret_key: RuntimeEnv.secret_key)
          token && Codec.encode(token)
        end

        # Decodes and verifies an encoded token, recording usage and the request strategy.
        #
        # @param encoded [String, nil]
        # @return [Html2rss::Web::FeedToken, nil]
        def validate(encoded)
          decoded = Codec.decode(encoded) or return

          validated = Signer.validate_decoded(decoded, decoded.url, RuntimeEnv.secret_key)
          if (strategy = validated&.strategy) && (context = RequestContext.current)
            RequestContext.set!(context.with(strategy:))
          end
          SecurityLogger.log_token_usage(encoded, decoded.url, !validated.nil?)
          validated
        end
      end

      ##
      # zlib + URL-safe Base64 codec for feed-token wire payloads.
      module Codec
        class << self
          # @param token [Html2rss::Web::FeedToken]
          # @return [String]
          def encode(token)
            compressed = Zlib::Deflate.deflate(wire_document(token).to_json)
            Base64.urlsafe_encode64(compressed)
          end

          # @param encoded_token [String, nil]
          # @return [Html2rss::Web::FeedToken, nil]
          def decode(encoded_token)
            return if encoded_token.nil? || encoded_token.bytesize > MAX_ENCODED_BYTES

            token_data = parse_token_data(encoded_token)
            return unless valid_token_data?(token_data)

            decoded_token(token_data)
          rescue JSON::ParserError, ArgumentError, Zlib::DataError, Zlib::BufError
            nil
          end

          private

          # @param token [Html2rss::Web::FeedToken]
          # @return [Hash{Symbol=>Object}]
          def wire_document(token)
            payload = { u: token.username, l: token.url, e: token.expires_at }
            payload[:t] = token.strategy if token.strategy
            payload[:c] = token.selectors if token.selectors
            { p: payload, s: token.signature }
          end

          # @param encoded_token [String]
          # @return [Hash{Symbol=>Object}]
          def parse_token_data(encoded_token)
            JSON.parse(inflate_bounded(Base64.urlsafe_decode64(encoded_token)), symbolize_names: true)
          end

          # Aborts once {MAX_INFLATED_BYTES} is exceeded instead of fully expanding a compression bomb.
          #
          # @param compressed [String]
          # @return [String]
          # @raise [Zlib::DataError] when the document inflates past the cap
          def inflate_bounded(compressed)
            stream = Zlib::Inflate.new
            buffer = +''
            stream.inflate(compressed) do |chunk|
              buffer << chunk
              raise Zlib::DataError, 'token payload exceeds the inflate cap' if buffer.bytesize > MAX_INFLATED_BYTES
            end
            buffer
          ensure
            stream&.close
          end

          # @param token_data [Hash{Symbol=>Object}]
          # @return [Html2rss::Web::FeedToken]
          def decoded_token(token_data)
            payload = token_data[:p]
            FeedToken.new(
              username: payload[:u],
              url: payload[:l],
              expires_at: payload[:e],
              signature: token_data[:s],
              strategy: payload[:t],
              selectors: payload[:c]
            )
          end

          # @param token_data [Object]
          # @return [Boolean]
          def valid_token_data?(token_data)
            return false unless token_data.is_a?(Hash)

            signature = token_data[:s]
            signature.is_a?(String) && !signature.empty? && valid_payload?(token_data[:p])
          end

          # @param payload [Object]
          # @return [Boolean]
          def valid_payload?(payload)
            payload.is_a?(Hash) &&
              payload[:u].is_a?(String) &&
              payload[:l].is_a?(String) &&
              payload[:e].is_a?(Integer) &&
              (payload[:t].nil? || payload[:t].is_a?(String)) &&
              valid_selectors?(payload[:c])
          end

          # @param selectors [Object]
          # @return [Boolean]
          def valid_selectors?(selectors)
            selectors.nil? || selectors.is_a?(Hash)
          end
        end
      end

      ##
      # HMAC-SHA256 creation and verification for feed tokens.
      module Signer
        HMAC_ALGORITHM = 'SHA256'

        class << self
          # @param username [String]
          # @param url [String]
          # @param secret_key [String]
          # @param strategy [String, nil]
          # @param selectors [Hash{Symbol=>Object}, nil]
          # @param expires_in [Integer]
          # @return [Html2rss::Web::FeedToken, nil]
          def create(username:, url:, secret_key:, strategy: nil, selectors: nil, expires_in: DEFAULT_EXPIRY) # rubocop:disable Metrics/ParameterLists
            return unless valid_inputs?(username, url, secret_key, strategy, selectors)

            expires_at = Time.now.to_i + expires_in.to_i
            signature = sign(secret_key, signature_payload(username, url, expires_at, strategy, selectors))
            FeedToken.new(username:, url:, expires_at:, signature:, strategy:, selectors:)
          end

          # Validates signature, URL binding, and expiry for an already-decoded token.
          #
          # @param token [Html2rss::Web::FeedToken, nil]
          # @param expected_url [String, nil]
          # @param secret_key [String]
          # @return [Html2rss::Web::FeedToken, nil]
          def validate_decoded(token, expected_url, secret_key)
            return unless token
            return unless valid_signature?(token, secret_key)
            return unless token.valid_for_url?(expected_url)
            return if token.expired?

            token
          end

          # @param token [Html2rss::Web::FeedToken]
          # @param secret_key [String]
          # @return [Boolean]
          def valid_signature?(token, secret_key)
            return false unless secret_key.is_a?(String) && !secret_key.empty?

            expected_signature = sign(secret_key, signature_payload(
                                                    token.username, token.url, token.expires_at,
                                                    token.strategy, token.selectors
                                                  ))
            signatures_match?(token.signature, expected_signature)
          end

          private

          # @param username [String]
          # @param url [String]
          # @param expires_at [Integer]
          # @param strategy [String, nil]
          # @param selectors [Hash{Symbol=>Object}, nil]
          # @return [Hash{Symbol=>Object}]
          def signature_payload(username, url, expires_at, strategy, selectors)
            payload = { username:, url:, expires_at: }
            payload[:strategy] = strategy if strategy
            payload[:selectors] = selectors if selectors
            payload
          end

          # @param secret_key [String]
          # @param payload [Hash]
          # @return [String]
          def sign(secret_key, payload)
            OpenSSL::HMAC.hexdigest(HMAC_ALGORITHM, secret_key, JSON.generate(payload))
          end

          # @param first [String, nil]
          # @param second [String]
          # @return [Boolean]
          def signatures_match?(first, second)
            return false unless first

            OpenSSL.secure_compare(first, second)
          end

          # @param username [Object]
          # @param url [Object]
          # @param secret_key [Object]
          # @param strategy [Object]
          # @param selectors [Object]
          # @return [Boolean]
          def valid_inputs?(username, url, secret_key, strategy, selectors)
            valid_username?(username) && UrlValidator.valid_url?(url) && valid_secret_key?(secret_key) &&
              valid_strategy?(strategy) && (selectors.nil? || selectors.is_a?(Hash))
          end

          # @param username [Object]
          # @return [Boolean]
          def valid_username?(username)
            username.is_a?(String) && username.length <= 100 && username.match?(/\A[a-zA-Z0-9_-]+\z/)
          end

          # @param secret_key [Object]
          # @return [Boolean]
          def valid_secret_key?(secret_key)
            secret_key.is_a?(String) && !secret_key.empty?
          end

          # @param strategy [Object]
          # @return [Boolean]
          def valid_strategy?(strategy)
            return true if strategy.nil?

            strategy.is_a?(String) && strategy.length <= 50 && strategy.match?(/\A[a-z0-9_]+\z/)
          end
        end
      end
    end
  end
end
