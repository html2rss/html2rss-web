# frozen_string_literal: true

require 'base64'
require 'json'
require 'openssl'
require 'zlib'
require_relative 'url_validator'

module Html2rss
  module Web
    DEFAULT_EXPIRY = 315_360_000 # 10 years in seconds
    HMAC_ALGORITHM = 'SHA256'
    REQUIRED_TOKEN_KEYS = %i[p s].freeze
    COMPRESSED_PAYLOAD_KEYS = %i[u l e].freeze

    FeedToken = Data.define(:username, :url, :expires_at, :signature) do
      def self.create_with_validation(username:, url:, secret_key:, expires_in: DEFAULT_EXPIRY)
        return unless valid_inputs?(username, url, secret_key)

        expires_at = Time.now.to_i + expires_in.to_i
        payload = build_payload(username, url, expires_at)
        signature = generate_signature(secret_key, payload)

        new(username: username, url: url, expires_at: expires_at, signature: signature)
      end

      def self.decode(encoded_token) # rubocop:disable Metrics/MethodLength
        return unless encoded_token

        token_data = parse_token_data(encoded_token)
        return unless valid_token_data?(token_data)

        payload = token_data[:p]
        new(
          username: payload[:u],
          url: payload[:l],
          expires_at: payload[:e],
          signature: token_data[:s]
        )
      rescue JSON::ParserError, ArgumentError, Zlib::DataError, Zlib::BufError
        nil
      end

      def self.validate_and_decode(encoded_token, expected_url, secret_key)
        token = decode(encoded_token)
        return unless token
        return unless token.valid_signature?(secret_key)
        return unless token.valid_for_url?(expected_url)
        return if token.expired?

        token
      end

      def encode
        compressed = Zlib::Deflate.deflate(build_token_data.to_json)
        Base64.urlsafe_encode64(compressed)
      end

      def expired?
        Time.now.to_i > expires_at
      end

      def valid_for_url?(candidate_url)
        url == candidate_url
      end

      def valid_signature?(secret_key)
        return false unless self.class.valid_secret_key?(secret_key)

        expected_signature = self.class.generate_signature(secret_key, payload_for_signature)
        secure_compare(signature, expected_signature)
      end

      private

      def payload_for_signature
        { username: username, url: url, expires_at: expires_at }
      end

      def build_token_data
        { p: { u: username, l: url, e: expires_at }, s: signature }
      end

      def secure_compare(first, second) # rubocop:disable Naming/PredicateMethod
        return false unless first && second && first.bytesize == second.bytesize

        first.each_byte.zip(second.each_byte).reduce(0) { |acc, (a, b)| acc | (a ^ b) }.zero?
      end

      class << self
        def build_payload(username, url, expires_at)
          { username: username, url: url, expires_at: expires_at }
        end

        def generate_signature(secret_key, payload)
          data = payload.is_a?(String) ? payload : JSON.generate(payload)
          OpenSSL::HMAC.hexdigest(HMAC_ALGORITHM, secret_key, data)
        end

        def parse_token_data(encoded_token)
          decoded = Base64.urlsafe_decode64(encoded_token)
          inflated = Zlib::Inflate.inflate(decoded)
          JSON.parse(inflated, symbolize_names: true)
        end

        def valid_token_data?(token_data)
          return false unless token_data.is_a?(Hash)

          payload = token_data[:p]
          signature = token_data[:s]
          payload.is_a?(Hash) && signature.is_a?(String) && !signature.empty? &&
            COMPRESSED_PAYLOAD_KEYS.all? { |key| payload[key] }
        end

        def valid_inputs?(username, url, secret_key)
          valid_username?(username) && UrlValidator.valid_url?(url) && valid_secret_key?(secret_key)
        end

        def valid_username?(username)
          username.is_a?(String) && !username.empty? && username.length <= 100 && username.match?(/\A[a-zA-Z0-9_-]+\z/)
        end

        def valid_secret_key?(secret_key)
          secret_key.is_a?(String) && !secret_key.empty?
        end
      end
    end
  end
end
