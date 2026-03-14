# frozen_string_literal: true

require 'html2rss'
require 'json'

require_relative 'auth'
require_relative 'feed_response_format'
require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Feeds functionality for generating RSS feeds
    module Feeds
      class << self
        # Builds and renders a configured RSS feed by feed name.
        #
        # @param feed_name [String]
        # @param params [Hash{Symbol=>Object}]
        # @param format [Symbol]
        # @return [String] rendered feed output.
        def generate_feed(feed_name, params = {}, format: FeedResponseFormat::RSS)
          config = LocalConfig.find(feed_name)
          config[:params] = (config[:params] || {}).merge(params) if params.any?
          config[:strategy] ||= Html2rss::RequestService.default_strategy_name

          return JSON.generate(Html2rss.json_feed(config)) if format == FeedResponseFormat::JSON_FEED

          Html2rss.feed(config).to_s
        end
      end
    end
  end
end
