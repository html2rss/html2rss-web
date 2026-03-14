# frozen_string_literal: true

require_relative 'cache'
require_relative 'result'

module Html2rss
  module Web
    module Feeds
      ##
      # Shared synchronous feed service around the html2rss gem.
      module Service
        class << self
          # @param resolved_source [Html2rss::Web::Feeds::ResolvedSource]
          # @return [Html2rss::Web::Feeds::Result]
          def call(resolved_source)
            cache_key = "feed_result:#{resolved_source.cache_identity}"

            Cache.fetch(cache_key, ttl_seconds: resolved_source.ttl_seconds) do
              build_result(resolved_source, cache_key)
            end
          end

          private

          # @param resolved_source [Html2rss::Web::Feeds::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Result]
          def build_result(resolved_source, cache_key)
            feed = Html2rss.feed(resolved_source.generator_input)

            Result.new(
              status: result_status(feed),
              payload: payload_for(feed, resolved_source),
              message: nil,
              ttl_seconds: resolved_source.ttl_seconds,
              cache_key: cache_key
            )
          rescue StandardError => error
            error_result(error, resolved_source, cache_key)
          end

          # @param feed [Object]
          # @return [Boolean]
          def feed_has_items?(feed)
            feed.respond_to?(:items) && !feed.items.empty?
          end

          # @param feed [Object]
          # @return [Symbol]
          def result_status(feed)
            feed_has_items?(feed) ? :ok : :empty
          end

          # @param feed [Object]
          # @param resolved_source [Html2rss::Web::Feeds::ResolvedSource]
          # @return [Hash{Symbol=>Object}]
          def payload_for(feed, resolved_source)
            {
              feed: feed,
              url: resolved_source.generator_input.dig(:channel, :url),
              strategy: resolved_source.generator_input[:strategy].to_s
            }
          end

          # @param error [StandardError]
          # @param resolved_source [Html2rss::Web::Feeds::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Result]
          def error_result(error, resolved_source, cache_key)
            Result.new(
              status: :error,
              payload: nil,
              message: error.message,
              ttl_seconds: resolved_source.ttl_seconds,
              cache_key: cache_key
            )
          end
        end
      end
    end
  end
end
