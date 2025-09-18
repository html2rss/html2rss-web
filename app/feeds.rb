# frozen_string_literal: true

require_relative 'auth'

module Html2rss
  module Web
    ##
    # Feeds functionality for listing and generating RSS feeds
    module Feeds
      module_function

      def list_feeds
        LocalConfig.feed_names.map do |name|
          {
            name: name,
            url: "/api/#{name}",
            description: "RSS feed for #{name}"
          }
        end
      end

      def generate_feed(feed_name, params = {})
        config = LocalConfig.find(feed_name)
        config[:params] ||= {}
        config[:params].merge!(params)

        Html2rss.feed(config)
      end

      def error_feed(message)
        sanitized_message = Auth.sanitize_xml(message)
        build_error_rss(sanitized_message)
      end

      def build_error_rss(sanitized_message)
        <<~RSS
          <?xml version="1.0" encoding="UTF-8"?>
          <rss version="2.0">
            <channel>
              <title>Error</title>
              <description>Failed to generate feed: #{sanitized_message}</description>
              <item>
                <title>Error</title>
                <description>#{sanitized_message}</description>
              </item>
            </channel>
          </rss>
        RSS
      end
    end
  end
end
