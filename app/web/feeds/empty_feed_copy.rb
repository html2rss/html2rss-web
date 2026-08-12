# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Plain-text copy for empty feed HTTP responses.
      module EmptyFeedCopy
        DESCRIPTION_TEMPLATE = <<~DESC
          We could not extract entries from %<url>s right now.
          The source may block automated requests, require dynamic rendering, or be temporarily unavailable.
        DESC

        ITEM_TEMPLATE = <<~DESC
          No entries were extracted from %<url>s.

          What you can do:
          - Try again in a few moments
          - Open the original page to confirm content is available
          - Reach out to the site owner if access is restricted
        DESC

        class << self
          # @param url [String]
          # @param site_title [String, nil]
          # @return [String]
          def plain_text(url, site_title)
            [title(site_title), description(url), item(url)].join("\n\n")
          end

          private

          # @param site_title [String, nil]
          # @return [String]
          def title(site_title)
            site_title ? "#{site_title} - Content Extraction Issue" : 'Content Extraction Issue'
          end

          # @param url [String]
          # @return [String]
          def description(url)
            format(DESCRIPTION_TEMPLATE, url: url)
          end

          # @param url [String]
          # @return [String]
          def item(url)
            format(ITEM_TEMPLATE, url: url)
          end
        end
      end
    end
  end
end
