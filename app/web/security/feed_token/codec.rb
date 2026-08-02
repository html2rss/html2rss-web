# frozen_string_literal: true

require 'base64'
require 'json'
require 'zlib'

module Html2rss
  module Web
    class FeedToken
      ##
      # zlib + URL-safe Base64 codec for feed-token wire payloads.
      #
      # Wire shape is JSON +zlib+base64 of +{ p: { u, l, e, t? }, s }+.
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
            return unless encoded_token

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
            { p: payload, s: token.signature }
          end

          # @param encoded_token [String]
          # @return [Hash{Symbol=>Object}]
          def parse_token_data(encoded_token)
            inflated = Zlib::Inflate.inflate(Base64.urlsafe_decode64(encoded_token))
            JSON.parse(inflated, symbolize_names: true)
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
              strategy: payload[:t]
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
              (payload[:t].nil? || payload[:t].is_a?(String))
          end
        end
      end
    end
  end
end
