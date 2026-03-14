# frozen_string_literal: true

require_relative 'request'
require_relative 'response_format'

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
          # @return [Html2rss::Web::Feeds::Request]
          def call(request:, target_kind:, identifier:)
            representation = ResponseFormat.for_request(request)
            normalized_identifier = ResponseFormat.strip_known_extension(identifier)

            Request.new(
              target_kind: target_kind,
              representation: representation,
              feed_name: target_kind == :static ? normalized_identifier : nil,
              token: target_kind == :token ? normalized_identifier : nil,
              params: request.params.to_h
            )
          end
        end
      end
    end
  end
end
