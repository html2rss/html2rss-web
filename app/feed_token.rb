# frozen_string_literal: true

require 'base64'
require 'json'
require 'zlib'
require 'openssl'
require_relative 'url_validator'

module Html2rss
  module Web
    # Token configuration constants
    DEFAULT_EXPIRY = 315_360_000 # 10 years in seconds
    HMAC_ALGORITHM = 'SHA256'

    # Compressed feed token with HMAC validation
    FeedToken = Data.define(:username, :url, :expires_at, :signature) do
      # @param username [String]
      # @param url [String]
      # @param secret_key [String]
      # @param expires_in [Integer] seconds (default: 10 years)
      # @return [FeedToken, nil]
      def self.create_with_validation(username:, url:, secret_key:, expires_in: Html2rss::Web::DEFAULT_EXPIRY)
        return nil unless valid_inputs?(username, url, secret_key)

        expires_at = Time.now.to_i + expires_in.to_i
        payload = create_payload(username, url, expires_at)
        signature = generate_signature(secret_key, payload)

        new(username: username, url: url, expires_at: expires_at, signature: signature)
      end

      # @param encoded_token [String]
      # @return [FeedToken, nil]
      def self.decode(encoded_token)
        return nil unless encoded_token

        token_data = parse_token_data(encoded_token)
        return nil unless valid_token_data?(token_data)

        create_from_token_data(token_data)
      rescue JSON::ParserError, ArgumentError, Zlib::DataError, Zlib::BufError
        nil
      end

      # @return [String] compressed base64-encoded token
      def encode
        token_data = build_token_data
        compressed_data = Zlib::Deflate.deflate(token_data.to_json)
        Base64.urlsafe_encode64(compressed_data)
      end

      # @return [Boolean]
      def expired?
        Time.now.to_i > expires_at
      end

      # @param url [String]
      # @return [Boolean]
      def valid_for_url?(url)
        self.url == url
      end

      # @param encoded_token [String]
      # @param expected_url [String]
      # @param secret_key [String]
      # @return [FeedToken, nil]
      def self.validate_and_decode(encoded_token, expected_url, secret_key)
        token = decode(encoded_token)
        return nil unless token

        return nil unless token.valid_signature?(secret_key)
        return nil unless token.valid_for_url?(expected_url)
        return nil if token.expired?

        token
      end

      # @return [Hash] payload for HMAC verification
      def payload_for_signature
        {
          username: username,
          url: url,
          expires_at: expires_at
        }
      end

      # @param username [String]
      # @param url [String]
      # @param secret_key [String]
      # @return [Boolean]
      def self.valid_inputs?(username, url, secret_key)
        valid_username?(username) && UrlValidator.valid_url?(url) && secret_key
      end

      # @param secret_key [String]
      # @return [Boolean]
      def valid_signature?(secret_key)
        return false unless secret_key

        expected_signature = self.class.generate_signature(secret_key, payload_for_signature)
        secure_compare(signature, expected_signature)
      end

      private

      # @param encoded_token [String]
      # @return [Hash, nil]
      def self.parse_token_data(encoded_token)
        compressed_data = Base64.urlsafe_decode64(encoded_token)
        json_data = Zlib::Inflate.inflate(compressed_data)
        JSON.parse(json_data, symbolize_names: true)
      end

      # @param token_data [Hash]
      # @return [Boolean]
      def self.valid_token_data?(token_data)
        return false unless token_data[:p] && token_data[:s]

        payload = token_data[:p]
        payload[:u] && payload[:l] && payload[:e]
      end

      # @param token_data [Hash]
      # @return [FeedToken]
      def self.create_from_token_data(token_data)
        payload = token_data[:p]
        new(
          username: payload[:u],
          url: payload[:l],
          expires_at: payload[:e],
          signature: token_data[:s]
        )
      end

      # @return [Hash]
      def build_token_data
        compressed_payload = {
          u: username,
          l: url,
          e: expires_at
        }

        {
          p: compressed_payload,
          s: signature
        }
      end

      # @param username [String]
      # @param url [String]
      # @param expires_at [Integer]
      # @return [Hash]
      def self.create_payload(username, url, expires_at)
        {
          username: username,
          url: url,
          expires_at: expires_at
        }
      end

      # @param secret_key [String]
      # @param payload [Hash]
      # @return [String]
      def self.generate_signature(secret_key, payload)
        OpenSSL::HMAC.hexdigest(Html2rss::Web::HMAC_ALGORITHM, secret_key, payload.to_json)
      end

      # @param username [String]
      # @return [Boolean]
      def self.valid_username?(username)
        return false unless username.is_a?(String)
        return false if username.empty? || username.length > 100
        return false unless username.match?(/\A[a-zA-Z0-9_-]+\z/)

        true
      end

      # @param url [String]
      # @return [Boolean]
      def self.valid_url?(url)
        UrlValidator.valid_url?(url)
      end

      # Constant-time comparison to prevent timing attacks
      # @param first_string [String]
      # @param second_string [String]
      # @return [Boolean]
      def secure_compare(first_string, second_string)
        return false unless first_string && second_string
        return false unless first_string.bytesize == second_string.bytesize

        result = 0
        first_string.bytes.zip(second_string.bytes) { |x, y| result |= x ^ y }
        result.zero?
      end
    end
  end
end
