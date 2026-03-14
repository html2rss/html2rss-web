# frozen_string_literal: true

require_relative '../rendering/feed_response_format'
require_relative '../feeds/json_renderer'
require_relative '../feeds/rss_renderer'
require_relative '../domain/feed_contracts'
require_relative 'http_cache'

module Html2rss
  module Web
    module Http
      ##
      # Writes feed results to an HTTP response in a representation-aware way.
      module FeedResponse
        class << self
          # @param response [Rack::Response]
          # @param representation [Symbol]
          # @param result [Html2rss::Web::FeedContracts::RenderResult]
          # @return [String]
          def call(response:, representation:, result:)
            response.status = response_status(result)
            response['Content-Type'] = FeedResponseFormat.content_type(representation)
            apply_cache_headers(response, result)
            HttpCache.vary(response, 'Accept')
            render_result(result, representation)
          end

          private

          # @param result [Html2rss::Web::FeedContracts::RenderResult]
          # @return [Integer]
          def response_status(result)
            result.status == :error ? 500 : 200
          end

          # @param response [Rack::Response]
          # @param result [Html2rss::Web::FeedContracts::RenderResult]
          # @return [void]
          def apply_cache_headers(response, result)
            return HttpCache.expires_now(response) if result.status == :error

            HttpCache.expires(response, result.ttl_seconds, cache_control: 'public')
          end

          # @param result [Html2rss::Web::FeedContracts::RenderResult]
          # @param representation [Symbol]
          # @return [String]
          def render_result(result, representation)
            return Feeds::JsonRenderer.call(result) if representation == FeedResponseFormat::JSON_FEED

            Feeds::RssRenderer.call(result)
          end
        end
      end
    end
  end
end
