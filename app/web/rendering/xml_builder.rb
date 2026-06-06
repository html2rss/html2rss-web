# frozen_string_literal: true

require 'rss'
require 'time'

module Html2rss
  module Web
    ##
    # Central RSS/XML rendering helpers.
    #
    # XML shaping is centralized so endpoints/services can return consistent feed
    # output without duplicating channel/item boilerplate.
    module XmlBuilder
      class << self
        # @param title [String]
        # @param description [String]
        # @param link [String, nil]
        # @param items [Array<Hash{Symbol=>Object}>]
        # @param timestamp [Time, nil]
        # @return [String] serialized RSS XML document.
        def build_rss_feed(title:, description:, link: nil, items: [], timestamp: nil)
          RSS::Maker.make('2.0') do |maker|
            apply_stylesheets(maker)
            build_channel(maker.channel, title:, description:, link:, timestamp:)
            build_items(maker, items, default_timestamp: timestamp)
          end.to_s
        end

        # @param message [String]
        # @param title [String]
        # @return [String] single-item RSS error document.
        def build_error_feed(message:, title: 'Error')
          build_single_item_feed(
            title:,
            description: "Failed to generate feed: #{message}",
            item: {
              title:,
              description: message
            }
          )
        end

        # @param url [String]
        # @param strategy [String]
        # @param site_title [String, nil]
        # @return [String] RSS warning document when extraction yields no content.
        def build_empty_feed_warning(url:, strategy:, site_title: nil)
          build_single_item_feed(
            title: FeedNoticeText.empty_feed_title(site_title),
            description: FeedNoticeText.empty_feed_description(url: url, strategy: strategy),
            item: { title: 'Preview unavailable for this source', description: FeedNoticeText.empty_feed_item(url: url),
                    link: url },
            link: url
          )
        end

        private

        # @param maker [RSS::Maker::RSS20]
        # @return [void]
        def apply_stylesheets(maker)
          # Use the gem's internal stylesheet support.
          stylesheets = Html2rss.configuration.stylesheets.map do |s|
            Html2rss::RssBuilder::Stylesheet.new(**s)
          end
          Html2rss::RssBuilder::Stylesheet.add(maker, stylesheets)
        end

        # @param title [String]
        # @param description [String]
        # @param item [Hash{Symbol=>Object}]
        # @param link [String, nil]
        # @return [String]
        def build_single_item_feed(title:, description:, item:, link: nil)
          timestamp = Time.now
          build_rss_feed(
            title:,
            description:,
            link:,
            items: [feed_item(item, timestamp:)],
            timestamp:
          )
        end

        # @param item [Hash{Symbol=>Object}]
        # @param timestamp [Time]
        # @return [Hash{Symbol=>Object}] normalized item with required RSS fields.
        def feed_item(item, timestamp:)
          {
            title: item[:title],
            description: item[:description],
            link: item[:link],
            pubDate: timestamp
          }
        end

        # @param channel [RSS::Maker::RSS20::Channel]
        # @param title [String]
        # @param description [String]
        # @param link [String, nil]
        # @param timestamp [Time, nil]
        # @return [void]
        def build_channel(channel, title:, description:, link:, timestamp:)
          now = timestamp || Time.now
          channel.title = title.to_s
          channel.description = description.to_s
          channel.link = link.to_s
          channel.lastBuildDate = now
          channel.pubDate = now
        end

        # @param maker [RSS::Maker::RSS20]
        # @param items [Array<Hash{Symbol=>Object}>]
        # @param default_timestamp [Time, nil]
        # @return [void]
        def build_items(maker, items, default_timestamp:)
          items.each do |item|
            maker.items.new_item do |i|
              i.title = item[:title].to_s
              i.description = item[:description].to_s
              i.link = item[:link].to_s
              i.pubDate = item[:pubDate] || default_timestamp || Time.now
            end
          end
        end
      end
    end
  end
end
