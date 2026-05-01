# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Shared copy helpers for rendered feed warnings and fallback documents.
    module FeedNoticeText
      EMPTY_FEED_DESCRIPTION_TEMPLATE = <<~DESC
        We could not extract entries from %<url>s right now.
        The source may block automated requests, require dynamic rendering, or be temporarily unavailable.
      DESC

      EMPTY_FEED_ITEM_TEMPLATE = <<~DESC
        No entries were extracted from %<url>s.

        What you can do:
        - Try again in a few moments
        - Open the original page to confirm content is available
        - Reach out to the site owner if access is restricted
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
