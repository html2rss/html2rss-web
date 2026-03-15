# frozen_string_literal: true

require 'base64'
require 'json'
require 'openssl'
require 'zlib'
module Html2rss
  module Web # rubocop:disable Metrics/ModuleLength
    ##
    # Immutable feed token value object with encode/decode and validation helpers.
    #
    # It keeps signing, validation, and payload shaping in one place so auth
    # callers can treat tokens as a single boundary contract.
    FeedToken = Data.define(:username, :url, :expires_at, :signature, :strategy) do
      # @param username [String]
      # @param url [String]
      # @param secret_key [String]
      # @param strategy [String]
      # @param expires_in [Integer]
      # @return [Html2rss::Web::FeedToken, nil] signed token object when inputs are valid.
      def self.create_with_validation(username:, url:, secret_key:, strategy:, expires_in: FeedToken::DEFAULT_EXPIRY)
        return unless valid_inputs?(username, url, secret_key, strategy)

        expires_at = Time.now.to_i + expires_in.to_i
        payload = build_payload(username, url, expires_at, strategy)
        signature = generate_signature(secret_key, payload)

        new(username: username, url: url, expires_at: expires_at, signature: signature, strategy: strategy)
      end

      # @param encoded_token [String, nil]
      # @return [Html2rss::Web::FeedToken, nil] decoded token when payload is valid.
      def self.decode(encoded_token) # rubocop:disable Metrics/MethodLength
        return unless encoded_token

        token_data = parse_token_data(encoded_token)
        return unless valid_token_data?(token_data)

        payload = token_data[:p]
        new(
          username: payload[:u],
          url: payload[:l],
          expires_at: payload[:e],
          signature: token_data[:s],
          strategy: payload[:t]
        )
      rescue JSON::ParserError, ArgumentError, Zlib::DataError, Zlib::BufError
        nil
      end

      # @param encoded_token [String, nil]
      # @param expected_url [String, nil]
      # @param secret_key [String]
      # @return [Html2rss::Web::FeedToken, nil] validated token bound to expected URL.
      def self.validate_and_decode(encoded_token, expected_url, secret_key)
        token = decode(encoded_token)
        return unless token
        return unless token.valid_signature?(secret_key)
        return unless token.valid_for_url?(expected_url)
        return if token.expired?

        token
      end

      # @return [String] compressed + URL-safe token representation.
      def encode
        compressed = Zlib::Deflate.deflate(build_token_data.to_json)
        Base64.urlsafe_encode64(compressed)
      end

      # @return [Boolean] true when token expiration is in the past.
      def expired?
        Time.now.to_i > expires_at
      end

      # @param candidate_url [String]
      # @return [Boolean] true when candidate URL matches token URL exactly.
      def valid_for_url?(candidate_url)
        url == candidate_url
      end

      # @param secret_key [String]
      # @return [Boolean] true when signature matches payload under given key.
      def valid_signature?(secret_key)
        return false unless self.class.valid_secret_key?(secret_key)

        expected_signature = self.class.generate_signature(secret_key, payload_for_signature)
        secure_compare(signature, expected_signature)
      end

      private

      # @return [Hash{Symbol=>Object}] canonical payload used for signature checks.
      def payload_for_signature
        payload = { username: username, url: url, expires_at: expires_at }
        payload[:strategy] = strategy if strategy
        payload
      end

      # @return [Hash{Symbol=>Object}] compact token envelope.
      def build_token_data
        payload = { u: username, l: url, e: expires_at }
        payload[:t] = strategy if strategy
        { p: payload, s: signature }
      end

      # Constant-time compare prevents timing leaks on signature mismatch.
      #
      # @param first [String, nil]
      # @param second [String, nil]
      # @return [Boolean]
      def secure_compare(first, second) # rubocop:disable Naming/PredicateMethod
        return false unless first && second && first.bytesize == second.bytesize

        first.each_byte.zip(second.each_byte).reduce(0) { |acc, (a, b)| acc | (a ^ b) }.zero?
      end

      class << self
        # @param username [String]
        # @param url [String]
        # @param expires_at [Integer]
        # @param strategy [String]
        # @return [Hash{Symbol=>Object}] signature payload.
        def build_payload(username, url, expires_at, strategy)
          { username: username, url: url, expires_at: expires_at, strategy: strategy }
        end

        # @param secret_key [String]
        # @param payload [Hash, String]
        # @return [String] HMAC digest.
        def generate_signature(secret_key, payload)
          data = payload.is_a?(String) ? payload : JSON.generate(payload)
          OpenSSL::HMAC.hexdigest(FeedToken::HMAC_ALGORITHM, secret_key, data)
        end

        # @param encoded_token [String]
        # @return [Hash{Symbol=>Object}] parsed token envelope.
        def parse_token_data(encoded_token)
          decoded = Base64.urlsafe_decode64(encoded_token)
          inflated = Zlib::Inflate.inflate(decoded)
          JSON.parse(inflated, symbolize_names: true)
        end

        # @param token_data [Object]
        # @return [Boolean] true when structure contains required payload/signature keys.
        def valid_token_data?(token_data)
          return false unless token_data.is_a?(Hash)

          payload = token_data[:p]
          signature = token_data[:s]
          payload.is_a?(Hash) && signature.is_a?(String) && !signature.empty? &&
            FeedToken::COMPRESSED_PAYLOAD_KEYS.all? { |key| payload[key] }
        end

        # @param username [Object]
        # @param url [Object]
        # @param secret_key [Object]
        # @param strategy [Object]
        # @return [Boolean]
        def valid_inputs?(username, url, secret_key, strategy)
          valid_username?(username) && UrlValidator.valid_url?(url) && valid_secret_key?(secret_key) &&
            valid_strategy?(strategy)
        end

        # @param username [Object]
        # @return [Boolean]
        def valid_username?(username)
          username.is_a?(String) && !username.empty? && username.length <= 100 && username.match?(/\A[a-zA-Z0-9_-]+\z/)
        end

        # @param secret_key [Object]
        # @return [Boolean]
        def valid_secret_key?(secret_key)
          secret_key.is_a?(String) && !secret_key.empty?
        end

        # @param strategy [Object]
        # @return [Boolean]
        def valid_strategy?(strategy)
          strategy.is_a?(String) && !strategy.empty? && strategy.length <= 50 && strategy.match?(/\A[a-z0-9_]+\z/)
        end
      end
    end

    FeedToken::DEFAULT_EXPIRY = 315_360_000 # 10 years in seconds
    FeedToken::HMAC_ALGORITHM = 'SHA256'
    FeedToken::REQUIRED_TOKEN_KEYS = %i[p s].freeze
    FeedToken::COMPRESSED_PAYLOAD_KEYS = %i[u l e].freeze
  end
end
