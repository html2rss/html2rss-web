# frozen_string_literal: true

require 'json'
require 'time'
module Html2rss
  module Web
    ##
    # Central JSON Feed rendering helpers.
    module JsonFeedBuilder
      VERSION_URL = 'https://jsonfeed.org/version/1.1'

      class << self
        # @param message [String]
        # @param title [String]
        # @return [String] single-item JSON Feed error document.
        def build_error_feed(message:, title: 'Error')
          build_single_item_feed(
            title:,
            description: "Failed to generate feed: #{message}",
            item: {
              title:,
              content_text: message
            }
          )
        end

        # @param url [String]
        # @param strategy [String]
        # @param site_title [String, nil]
        # @return [String] JSON Feed warning document when extraction yields no content.
        def build_empty_feed_warning(url:, strategy:, site_title: nil)
          build_single_item_feed(
            title: FeedNoticeText.empty_feed_title(site_title),
            description: FeedNoticeText.empty_feed_description(url: url, strategy: strategy),
            home_page_url: url,
            item: empty_feed_item(url)
          )
        end

        private

        # @param title [String]
        # @param description [String]
        # @param item [Hash{Symbol=>Object}]
        # @param home_page_url [String, nil]
        # @return [String]
        def build_single_item_feed(title:, description:, item:, home_page_url: nil)
          payload = {
            version: VERSION_URL,
            title: title,
            home_page_url: home_page_url,
            description: description,
            items: [build_single_item(item)]
          }.compact

          JSON.generate(payload)
        end

        # @param item [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def build_single_item(item)
          timestamp = Time.now.utc.iso8601

          {
            id: item[:url] || "#{item[:title]}-#{timestamp}",
            url: item[:url],
            title: item[:title],
            content_text: item[:content_text],
            content_html: item[:content_html],
            date_published: timestamp
          }.compact
        end

        # @param url [String]
        # @return [Hash{Symbol=>String}]
        def empty_feed_item(url)
          {
            title: 'Content Extraction Failed',
            content_text: FeedNoticeText.empty_feed_item(url: url),
            url: url
          }
        end
      end
    end
  end
end
