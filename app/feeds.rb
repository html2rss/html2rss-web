# frozen_string_literal: true

require 'html2rss'

require_relative 'auth'
require_relative 'local_config'
require_relative 'xml_builder'

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

        config[:params] = (config[:params] || {}).merge(params) if params.any?

        config[:strategy] ||= Html2rss::RequestService.default_strategy_name

        Html2rss.feed(config)
      end

      def error_feed(message)
        XmlBuilder.build_error_feed(message: message)
      end
    end
  end
end
