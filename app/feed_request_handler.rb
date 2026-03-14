# frozen_string_literal: true

require 'digest'

require_relative 'cache_ttl'
require_relative 'feed_response_format'
require_relative 'feed_runtime'
require_relative 'feeds'
require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Resolves feed payload and TTL for route handlers.
    module FeedRequestHandler
      class << self
        # @param feed_name [String]
        # @param params [Hash]
        # @param format [Symbol]
        # @param async_refresh [Boolean]
        # @return [Array<(String, Integer)>] feed xml and cache ttl.
        def call(feed_name:, params:, format:, async_refresh: false)
          ttl_seconds = feed_ttl_seconds(feed_name)
          content = feed_content(feed_name, params, format, ttl_seconds, async_refresh)
          [content, ttl_seconds]
        end

        private

        # @param feed_name [String]
        # @return [Integer]
        def feed_ttl_seconds(feed_name)
          ttl_value = LocalConfig.find(feed_name)&.dig(:channel, :ttl)
          CacheTtl.seconds_from_minutes(ttl_value)
        end

        # @param feed_name [String]
        # @param params [Hash]
        # @param format [Symbol]
        # @param ttl_seconds [Integer]
        # @param async_refresh [Boolean]
        # @return [String]
        def feed_content(feed_name, params, format, ttl_seconds, async_refresh)
          FeedRuntime.read(
            key: feed_cache_key(feed_name, params),
            ttl_seconds: ttl_seconds,
            async_refresh: async_refresh
          ) do
            Feeds.generate_feed(feed_name, params, format:)
          end
        end

        # @param feed_name [String]
        # @param params [Hash]
        # @return [String]
        def feed_cache_key(feed_name, params)
          normalized_params = params.to_h.sort_by { |key, _| key.to_s }
          digest = Digest::SHA256.hexdigest(Marshal.dump(normalized_params))
          "local_feed:#{feed_name}:#{digest}"
        end
      end
    end
  end
end
