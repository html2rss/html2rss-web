# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'xml_builder'

module Html2rss
  module Web
    ##
    # Central JSON Feed rendering helpers.
    module JsonFeedBuilder
      VERSION_URL = 'https://jsonfeed.org/version/1.1'
      EMPTY_FEED_DESCRIPTION_TEMPLATE = XmlBuilder::EMPTY_FEED_DESCRIPTION_TEMPLATE
      EMPTY_FEED_ITEM_TEMPLATE = XmlBuilder::EMPTY_FEED_ITEM_TEMPLATE

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
        # @return [String] JSON Feed response describing authorization failure.
        def build_access_denied_feed(url)
          build_single_item_feed(
            title: 'Access Denied',
            description: 'This URL is not allowed for public auto source generation.',
            home_page_url: url,
            item: {
              title: 'Access Denied',
              content_text: "URL '#{url}' is not in the allowed list for public auto source.",
              url: url
            }
          )
        end

        # @param url [String]
        # @param strategy [String]
        # @param site_title [String, nil]
        # @return [String] JSON Feed warning document when extraction yields no content.
        def build_empty_feed_warning(url:, strategy:, site_title: nil)
          build_single_item_feed(
            title: empty_feed_title(site_title),
            description: format(EMPTY_FEED_DESCRIPTION_TEMPLATE, url:, strategy:),
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

        # @param site_title [String, nil]
        # @return [String]
        def empty_feed_title(site_title)
          site_title ? "#{site_title} - Content Extraction Issue" : 'Content Extraction Issue'
        end

        # @param url [String]
        # @return [Hash{Symbol=>String}]
        def empty_feed_item(url)
          {
            title: 'Content Extraction Failed',
            content_text: format(EMPTY_FEED_ITEM_TEMPLATE, url:),
            url: url
          }
        end

        # @param value [Time, DateTime, String, nil]
        # @return [String, nil]
        def format_time(value)
          return if value.nil?
          return value.iso8601 if value.respond_to?(:iso8601)

          Time.parse(value.to_s).utc.iso8601
        rescue ArgumentError
          value.to_s
        end
      end
    end
  end
end
