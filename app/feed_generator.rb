# frozen_string_literal: true

require_relative 'xml_builder'
require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Feed generation functionality
    module FeedGenerator
      class << self
        # @param url [String]
        # @param strategy [String, Symbol]
        # @return [String]
        def generate_feed_content(url, strategy = 'ssrf_filter')
          feed_content = call_strategy(url, strategy)
          process_feed_content(url, strategy, feed_content)
        end

        # @param url [String]
        # @param strategy [String, Symbol]
        # @return [String]
        def call_strategy(url, strategy)
          return error_feed('URL parameter required') if url.nil? || url.empty?

          global_config = LocalConfig.global

          config = {
            strategy: strategy.to_sym,
            channel: { url: url },
            auto_source: {}
          }

          config[:stylesheets] = global_config[:stylesheets] if global_config[:stylesheets]
          config[:headers] = global_config[:headers] if global_config[:headers]

          Html2rss.feed(config)
        end

        # @param url [String]
        # @param strategy [String, Symbol]
        # @param feed_content [#to_s]
        # @return [String]
        def process_feed_content(url, strategy, feed_content)
          return feed_content unless feed_content.respond_to?(:to_s)

          feed_xml = feed_content.to_s
          return feed_content if feed_xml.include?('<item>')

          create_empty_feed_warning(url: url, strategy: strategy)
        end

        private

        def create_empty_feed_warning(url:, strategy:)
          XmlBuilder.build_empty_feed_warning(
            url: url,
            strategy: strategy,
            site_title: Html2rss::Url.for_channel(url).channel_titleized
          )
        end

        def error_feed(message)
          XmlBuilder.build_error_feed(message: message)
        end
      end
    end
  end
end
