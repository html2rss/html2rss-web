# frozen_string_literal: true

require 'nokogiri'
require 'sanitize'

module Html2rss
  module Web
    ##
    # Safe XML builder for RSS feeds using Nokogiri
    # Prevents XML injection and ensures proper escaping
    module XmlBuilder
      module_function

      ##
      # Build an RSS 2.0 feed with proper XML escaping
      # @param title [String] Channel title
      # @param description [String] Channel description
      # @param link [String, nil] Channel link
      # @param items [Array<Hash>] Array of item hashes with :title, :description, :link, :pubDate
      # @return [String] Valid RSS XML
      def build_rss_feed(title:, description:, link: nil, items: [])
        doc = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.rss(version: '2.0') do
            xml.channel do
              build_channel_content(xml, title, description, link)
              build_items(xml, items)
            end
          end
        end

        doc.to_xml
      end

      ##
      # Build an error RSS feed
      # @param message [String] Error message
      # @param title [String, nil] Custom title (defaults to "Error")
      # @return [String] Valid RSS XML
      def build_error_feed(message:, title: 'Error')
        build_rss_feed(
          title: title,
          description: "Failed to generate feed: #{message}",
          items: [
            {
              title: title,
              description: message
            }
          ]
        )
      end

      ##
      # Build an access denied RSS feed
      # @param url [String] The denied URL
      # @return [String] Valid RSS XML
      # rubocop:disable Metrics/MethodLength
      def build_access_denied_feed(url)
        title = 'Access Denied'
        description = 'This URL is not allowed for public auto source generation.'
        item_description = "URL '#{url}' is not in the allowed list for public auto source."

        build_rss_feed(
          title: title,
          description: description,
          items: [
            {
              title: title,
              description: item_description
            }
          ]
        )
      end
      # rubocop:enable Metrics/MethodLength

      ##
      # Build an empty feed warning RSS
      # @param url [String] The URL that failed to extract content
      # @param strategy [String] The strategy that was used
      # @param site_title [String, nil] Extracted site title
      # @return [String] Valid RSS XML
      # rubocop:disable Metrics/MethodLength
      def build_empty_feed_warning(url:, strategy:, site_title: nil)
        display_title = site_title ? "#{site_title} - Content Extraction Issue" : 'Content Extraction Issue'
        description = <<~DESC
          Unable to extract content from #{url} using #{strategy} strategy.
          The site may use JavaScript, have anti-bot protection, or have a
          structure that's difficult to parse.
        DESC

        item_description = "No content could be extracted from #{url}. This could be due to:
• JavaScript-heavy site (try browserless strategy)
• Anti-bot protection
• Complex page structure
• Site blocking automated requests

Try a different strategy or contact the site administrator."

        build_rss_feed(
          title: display_title,
          description: description,
          link: url,
          items: [
            {
              title: 'Content Extraction Failed',
              description: item_description,
              link: url,
              pubDate: Time.now.rfc2822
            }
          ]
        )
      end
      # rubocop:enable Metrics/MethodLength

      def build_channel_content(xml, title, description, link)
        xml.title title.to_s
        xml.description description.to_s
        xml.link link.to_s if link
      end

      # rubocop:disable Metrics/AbcSize
      def build_items(xml, items)
        items.each do |item|
          xml.item do
            xml.title item[:title].to_s if item[:title]
            xml.description item[:description].to_s if item[:description]
            xml.link item[:link].to_s if item[:link]
            xml.pubDate item[:pubDate].to_s if item[:pubDate]
          end
        end
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
