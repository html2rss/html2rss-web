# frozen_string_literal: true

require 'cgi'
require_relative '../domain/feed_contracts'
require_relative '../rendering/feed_response_format'

module Html2rss
  module Web
    module Feeds
      ##
      # Parses route inputs into shared feed request contracts.
      module RequestParser
        class << self
          # @param request [Rack::Request]
          # @param target_kind [Symbol]
          # @param identifier [String]
          # @return [Html2rss::Web::FeedContracts::Request]
          def call(request:, target_kind:, identifier:)
            build_request(
              request: request,
              target_kind: target_kind,
              identifier: normalize_identifier(target_kind, FeedResponseFormat.strip_known_extension(identifier))
            )
          end

          private

          # @param request [Rack::Request]
          # @param target_kind [Symbol]
          # @param identifier [String]
          # @return [Html2rss::Web::FeedContracts::Request]
          def build_request(request:, target_kind:, identifier:)
            FeedContracts::Request.new(
              target_kind: target_kind,
              representation: FeedResponseFormat.for_request(request),
              feed_name: target_kind == :static ? identifier : nil,
              token: target_kind == :token ? identifier : nil,
              params: request.params.to_h
            )
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @return [String]
          def normalize_identifier(target_kind, identifier)
            return identifier unless target_kind == :token

            CGI.unescape(identifier)
          end
        end
      end
    end
  end
end
