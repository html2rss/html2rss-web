# frozen_string_literal: true

require_relative 'cache_ttl'
require_relative 'feed_render_result'
require_relative 'xml_builder'
require_relative 'feed_response_format'
require_relative 'json_feed_builder'
require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Feed generation functionality
    module FeedGenerator
      class << self
        # @param url [String]
        # @param strategy [String, Symbol]
        # @param format [Symbol]
        # @return [Html2rss::Web::FeedRenderResult]
        def generate_feed_result(url, strategy = 'ssrf_filter', format: FeedResponseFormat::RSS)
          config = strategy_config(url, strategy)
          feed_content = generate_from_config(config, format)
          body = process_feed_content(url, strategy, feed_content, format:)

          FeedRenderResult.new(body:, ttl_seconds: ttl_seconds_for(config))
        end

        # @param url [String]
        # @param strategy [String, Symbol]
        # @param format [Symbol]
        # @return [String]
        def generate_feed_content(url, strategy = 'ssrf_filter', format: FeedResponseFormat::RSS)
          generate_feed_result(url, strategy, format:).body
        end

        # @param url [String]
        # @param strategy [String, Symbol]
        # @param format [Symbol]
        # @return [String]
        def call_strategy(url, strategy, format: FeedResponseFormat::RSS)
          return nil if url.nil? || url.empty?

          generate_from_config(strategy_config(url, strategy), format)
        end

        # @param url [String]
        # @param strategy [String, Symbol]
        # @param feed_content [RSS::Rss, Hash, nil]
        # @param format [Symbol]
        # @return [String]
        def process_feed_content(url, strategy, feed_content, format: FeedResponseFormat::RSS)
          return error_feed('URL parameter required', format:) if feed_content.nil?
          return rendered_feed(feed_content, format) if feed_has_items?(feed_content)

          create_empty_feed_warning(url: url, strategy: strategy, format: format)
        end

        private

        # @param feed [RSS::Rss, Hash]
        # @return [Boolean]
        def feed_has_items?(feed)
          return !Array(feed[:items] || feed['items']).empty? if feed.is_a?(Hash)

          feed.respond_to?(:items) && !feed.items.empty?
        end

        # @param feed [RSS::Rss, Hash]
        # @param format [Symbol]
        # @return [String]
        def rendered_feed(feed, format)
          return JSON.generate(feed) if format == FeedResponseFormat::JSON_FEED

          feed.to_s
        end

        # @param url [String]
        # @param strategy [String, Symbol]
        # @param format [Symbol]
        # @return [String]
        def create_empty_feed_warning(url:, strategy:, format:)
          builder_for(format).build_empty_feed_warning(
            url: url,
            strategy: strategy,
            site_title: Html2rss::Url.for_channel(url).channel_titleized
          )
        end

        # @param message [String]
        # @param format [Symbol]
        # @return [String]
        def error_feed(message, format:)
          builder_for(format).build_error_feed(message: message)
        end

        # @param format [Symbol]
        # @return [Module]
        def builder_for(format)
          format == FeedResponseFormat::JSON_FEED ? JsonFeedBuilder : XmlBuilder
        end

        # @param config [Hash{Symbol=>Object}]
        # @param format [Symbol]
        # @return [RSS::Rss, Hash]
        def generate_from_config(config, format)
          return Html2rss.json_feed(config) if format == FeedResponseFormat::JSON_FEED

          Html2rss.feed(config)
        end

        # @param url [String]
        # @param strategy [String, Symbol]
        # @return [Hash{Symbol=>Object}]
        def strategy_config(url, strategy)
          LocalConfig.global
                     .slice(:stylesheets, :headers)
                     .merge(
                       strategy: strategy.to_sym,
                       channel: { url: url },
                       auto_source: {}
                     )
        end

        # @param config [Hash{Symbol=>Object}]
        # @return [Integer]
        def ttl_seconds_for(config)
          CacheTtl.seconds_from_minutes(config.dig(:channel, :ttl))
        end
      end
    end
  end
end
