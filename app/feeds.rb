# frozen_string_literal: true

require 'html2rss'

require_relative 'auth'
require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Feeds functionality for generating RSS feeds
    module Feeds
      class << self
        def generate_feed(feed_name, params = {})
          config = LocalConfig.find(feed_name)
          config[:params] = (config[:params] || {}).merge(params) if params.any?
          config[:strategy] ||= Html2rss::RequestService.default_strategy_name
          Html2rss.feed(config)
        end
      end
    end
  end
end
