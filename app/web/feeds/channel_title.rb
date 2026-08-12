# frozen_string_literal: true

require 'html2rss/url'

module Html2rss
  module Web
    module Feeds
      ##
      # Derives a human-readable channel title from a feed URL.
      module ChannelTitle
        class << self
          # @param url [String, nil]
          # @return [String, nil]
          def for(url)
            Html2rss::Url.for_channel(url).channel_titleized
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
