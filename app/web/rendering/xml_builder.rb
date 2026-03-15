# frozen_string_literal: true

require 'nokogiri'
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
          current_time = timestamp || Time.now
          formatted_now = format_pub_date(current_time)

          Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
            xml.rss(version: '2.0') do
              xml.channel do
                build_channel(xml, title:, description:, link:, now: formatted_now)
                build_items(xml, items, default_pub_date: formatted_now)
              end
            end
          end.doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
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
            item: { title: 'Content Extraction Failed', description: FeedNoticeText.empty_feed_item(url: url),
                    link: url },
            link: url
          )
        end

        private

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
          feed_item = {
            title: item[:title],
            description: item[:description],
            pubDate: timestamp
          }
          feed_item[:link] = item[:link] if item[:link]
          feed_item
        end

        # @param xml [Nokogiri::XML::Builder]
        # @param title [String]
        # @param description [String]
        # @param link [String, nil]
        # @param now [String]
        # @return [void]
        def build_channel(xml, title:, description:, link:, now:)
          xml.title(title.to_s)
          xml.description(description.to_s)
          xml.link(link.to_s) if link
          xml.lastBuildDate(now)
          xml.pubDate(now)
        end

        # @param xml [Nokogiri::XML::Builder]
        # @param items [Array<Hash{Symbol=>Object}>]
        # @param default_pub_date [String]
        # @return [void]
        def build_items(xml, items, default_pub_date:)
          items.each do |item|
            xml.item do
              append_text_node(xml, :title, item[:title])
              append_text_node(xml, :description, item[:description])
              append_text_node(xml, :link, item[:link])
              xml.pubDate(format_pub_date(item[:pubDate] || default_pub_date))
            end
          end
        end

        # @param xml [Nokogiri::XML::Builder]
        # @param node_name [Symbol]
        # @param value [Object]
        # @return [void]
        def append_text_node(xml, node_name, value)
          xml.public_send(node_name, value.to_s) if value
        end

        # @param pub_date [Time, String]
        # @return [String] RFC2822 date string for RSS output.
        def format_pub_date(pub_date)
          pub_date.is_a?(Time) ? pub_date.rfc2822 : pub_date.to_s
        end
      end
    end
  end
end
