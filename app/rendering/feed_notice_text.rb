# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Shared copy helpers for rendered feed warnings and fallback documents.
    module FeedNoticeText
      EMPTY_FEED_DESCRIPTION_TEMPLATE = <<~DESC
        Unable to extract content from %<url>s using the %<strategy>s strategy.
        The site may rely on JavaScript, block automated requests, or expose a structure that needs a different parser.
      DESC

      EMPTY_FEED_ITEM_TEMPLATE = <<~DESC
        No entries were extracted from %<url>s.
        Possible causes:
        - JavaScript-heavy site (try the browserless strategy)
        - Anti-bot protection
        - Complex or changing markup
        - Site blocking automated requests

        Try another strategy or reach out to the site owner.
      DESC

      class << self
        # @param site_title [String, nil]
        # @return [String]
        def empty_feed_title(site_title)
          site_title ? "#{site_title} - Content Extraction Issue" : 'Content Extraction Issue'
        end

        # @param url [String]
        # @param strategy [String]
        # @return [String]
        def empty_feed_description(url:, strategy:)
          format(EMPTY_FEED_DESCRIPTION_TEMPLATE, url: url, strategy: strategy)
        end

        # @param url [String]
        # @return [String]
        def empty_feed_item(url:)
          format(EMPTY_FEED_ITEM_TEMPLATE, url: url)
        end
      end
    end
  end
end
