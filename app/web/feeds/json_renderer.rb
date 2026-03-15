# frozen_string_literal: true

require 'json'
require 'time'

module Html2rss
  module Web
    module Feeds
      ##
      # Renders JSON Feed output from shared feed results.
      module JsonRenderer
        VERSION = 'https://jsonfeed.org/version/1.1'

        class << self
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [String]
          def call(result)
            case result.status
            when :ok
              JSON.generate(payload_for(result.payload.feed))
            when :empty
              empty_feed(result)
            else
              error_feed(result)
            end
          end

          private

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [String]
          def empty_feed(result)
            JsonFeedBuilder.build_empty_feed_warning(
              url: result.payload.url,
              strategy: result.payload.strategy,
              site_title: result.payload.site_title
            )
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [String]
          def error_feed(result)
            JsonFeedBuilder.build_error_feed(message: result.message || Html2rss::Web::HttpError::DEFAULT_MESSAGE)
          end

          # @param feed [RSS::Rss]
          # @return [Hash{Symbol=>Object}]
          def payload_for(feed)
            {
              version: VERSION,
              title: feed.channel.title,
              home_page_url: feed.channel.link,
              description: feed.channel.description,
              items: feed.items.map { |item| item_payload(item) }
            }.compact
          end

          # @param item [Object]
          # @return [Hash{Symbol=>Object}]
          def item_payload(item)
            {
              id: item.respond_to?(:guid) && item.guid ? item.guid.content : (item.link || item.title),
              url: item.link,
              title: item.title,
              content_text: item.description,
              date_published: published_at(item)
            }.compact
          end

          # @param item [Object]
          # @return [String, nil]
          def published_at(item)
            value = item.respond_to?(:pubDate) ? item.pubDate : nil
            return value.iso8601 if value.respond_to?(:iso8601)

            Time.parse(value.to_s).utc.iso8601 if value
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end
