# frozen_string_literal: true

require_relative 'xml_builder'
require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Feed generation functionality
    module FeedGenerator
      module_function

      def generate_feed_content(url, strategy = 'ssrf_filter')
        feed_content = call_strategy(url, strategy)
        process_feed_content(url, strategy, feed_content)
      end

      def call_strategy(url, strategy) # rubocop:disable Metrics/MethodLength
        return error_feed('URL parameter required') if url.nil? || url.empty?

        global_config = LocalConfig.global

        config = {
          strategy: strategy.to_sym,
          channel: {
            url: url
          },
          auto_source: {
            # Auto source configuration placeholder for gem integration
          }
        }

        config[:stylesheets] = global_config[:stylesheets] if global_config[:stylesheets]
        config[:headers] = global_config[:headers] if global_config[:headers]

        Html2rss.feed(config)
      end

      def process_feed_content(url, strategy, feed_content, site_title: nil)
        return feed_content unless feed_content.respond_to?(:to_s)

        feed_xml = feed_content.to_s
        return feed_content if feed_xml.include?('<item>')

        create_empty_feed_warning(url: url, strategy: strategy, site_title: site_title)
      end

      def create_empty_feed_warning(url:, strategy:, site_title: nil)
        XmlBuilder.build_empty_feed_warning(
          url: url,
          strategy: strategy,
          site_title: site_title || extract_site_title(url)
        )
      end

      def extract_site_title(url)
        Html2rss::Url.for_channel(url).channel_titleized
      rescue StandardError
        nil
      end

      def error_feed(message)
        XmlBuilder.build_error_feed(message: message)
      end

      def access_denied_feed(url)
        XmlBuilder.build_access_denied_feed(url)
      end
    end
  end
end
