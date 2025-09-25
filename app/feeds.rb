# frozen_string_literal: true

require 'html2rss'

require_relative 'auth'
require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Feeds functionality for listing and generating RSS feeds
    module Feeds
      module_function

      def list_feeds
        LocalConfig.feed_names.map do |name|
          {
            id: name.to_s,
            name: name.to_s,
            description: "RSS feed for #{name}",
            public_url: "/#{name}"
          }
        end
      end

      def generate_feed(feed_name, params = {})
        config = LocalConfig.find(feed_name)
        config[:params] = (config[:params] || {}).merge(params) if params.any?
        config[:strategy] ||= Html2rss::RequestService.default_strategy_name
        Html2rss.feed(config)
      end
    end
  end
end
