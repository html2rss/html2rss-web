# frozen_string_literal: true

require 'nokogiri'
require 'time'

module Html2rss
  module Web
    module XmlBuilder
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

        def build_error_feed(message:, title: 'Error')
          now = Time.now
          build_rss_feed(
            title:,
            description: "Failed to generate feed: #{message}",
            items: [
              {
                title:,
                description: message,
                pubDate: now
              }
            ],
            timestamp: now
          )
        end

        def build_access_denied_feed(url)
          now = Time.now
          build_rss_feed(
            title: 'Access Denied',
            description: 'This URL is not allowed for public auto source generation.',
            items: [
              {
                title: 'Access Denied',
                description: "URL '#{url}' is not in the allowed list for public auto source.",
                pubDate: now
              }
            ],
            timestamp: now
          )
        end

        def build_empty_feed_warning(url:, strategy:, site_title: nil)
          now = Time.now
          build_rss_feed(
            title: site_title ? "#{site_title} - Content Extraction Issue" : 'Content Extraction Issue',
            description: format(EMPTY_FEED_DESCRIPTION_TEMPLATE, url:, strategy:),
            link: url,
            items: [
              {
                title: 'Content Extraction Failed',
                description: format(EMPTY_FEED_ITEM_TEMPLATE, url:),
                link: url,
                pubDate: now
              }
            ],
            timestamp: now
          )
        end

        private

        def build_channel(xml, title:, description:, link:, now:)
          xml.title(title.to_s)
          xml.description(description.to_s)
          xml.link(link.to_s) if link
          xml.lastBuildDate(now)
          xml.pubDate(now)
        end

        def build_items(xml, items, default_pub_date:)
          items.each do |item|
            xml.item do
              if (title = item[:title])
                xml.title(title.to_s)
              end

              if (description = item[:description])
                xml.description(description.to_s)
              end

              if (link = item[:link])
                xml.link(link.to_s)
              end

              if (pub_date = item[:pubDate])
                xml.pubDate(format_pub_date(pub_date))
              else
                xml.pubDate(default_pub_date)
              end
            end
          end
        end

        def format_pub_date(pub_date)
          pub_date.is_a?(Time) ? pub_date.rfc2822 : pub_date.to_s
        end
      end
    end
  end
end
