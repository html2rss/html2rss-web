# frozen_string_literal: true

require 'json'
require 'openssl'

module Html2rss
  module Web
    class FeedToken
      ##
      # HMAC-SHA256 creation and verification for feed tokens.
      module Signer
        HMAC_ALGORITHM = 'SHA256'

        class << self
          # @param username [String]
          # @param url [String]
          # @param secret_key [String]
          # @param strategy [String, nil]
          # @param expires_in [Integer]
          # @return [Html2rss::Web::FeedToken, nil]
          def create(username:, url:, secret_key:, strategy: nil, expires_in: FeedToken::DEFAULT_EXPIRY)
            return unless valid_inputs?(username, url, secret_key, strategy)

            expires_at = Time.now.to_i + expires_in.to_i
            signature = sign(secret_key, signature_payload(username, url, expires_at, strategy))
            FeedToken.new(username:, url:, expires_at:, signature:, strategy:)
          end

          # @param encoded_token [String, nil]
          # @param expected_url [String, nil]
          # @param secret_key [String]
          # @return [Html2rss::Web::FeedToken, nil]
          def validate(encoded_token, expected_url, secret_key)
            token = Codec.decode(encoded_token)
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
                                                    token.username, token.url, token.expires_at, token.strategy
                                                  ))
            signatures_match?(token.signature, expected_signature)
          end

          private

          # @param username [String]
          # @param url [String]
          # @param expires_at [Integer]
          # @param strategy [String, nil]
          # @return [Hash{Symbol=>Object}]
          def signature_payload(username, url, expires_at, strategy)
            payload = { username:, url:, expires_at: }
            payload[:strategy] = strategy if strategy
            payload
          end

          # @param secret_key [String]
          # @param payload [Hash, String]
          # @return [String]
          def sign(secret_key, payload)
            data = payload.is_a?(String) ? payload : JSON.generate(payload)
            OpenSSL::HMAC.hexdigest(HMAC_ALGORITHM, secret_key, data)
          end

          # @param first [String, nil]
          # @param second [String, nil]
          # @return [Boolean]
          def signatures_match?(first, second)
            return false unless first && second && first.bytesize == second.bytesize

            first.each_byte.zip(second.each_byte).reduce(0) { |acc, (a, b)| acc | (a ^ b) }.zero?
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
            username.is_a?(String) && !username.empty? && username.length <= 100 &&
              username.match?(/\A[a-zA-Z0-9_-]+\z/)
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

            strategy.is_a?(String) && !strategy.empty? && strategy.length <= 50 && strategy.match?(/\A[a-z0-9_]+\z/)
          end
        end
      end
    end
  end
end
