# frozen_string_literal: true

module Html2rss
  class HtmlExtractor
    ##
    # Extracts enclosures from HTML tags using various strategies.
    class EnclosureExtractor
      # @param article_tag [Nokogiri::XML::Element] article container node
      # @param base_url [String, Html2rss::Url] base URL for relative enclosure links
      # @return [Array<Hash{Symbol => Object}>] normalized enclosure hashes
      def self.call(article_tag, base_url)
        [
          Extractors::Image,
          Extractors::Media,
          Extractors::Pdf,
          Extractors::Iframe,
          Extractors::Archive
        ].flat_map { |strategy| strategy.call(article_tag, base_url:) }
      end
    end

    # Extraction strategies for enclosure-like media/link tags.
    module Extractors
      # Extracts image enclosures from HTML tags.
      # Finds all image sources and returns them in a format suitable for RSS.
      class Image
        # @param article_tag [Nokogiri::XML::Element] article container node
        # @param base_url [String, Html2rss::Url] base URL for relative image sources
        # @return [Array<Hash{Symbol => Object}>] image enclosure hashes
        def self.call(article_tag, base_url:)
          article_tag.css('img[src]:not([src^="data"])').filter_map do |img|
            src = img['src'].to_s
            next if src.empty?

            abs_url = Url.from_relative(src, base_url)
            {
              url: abs_url,
              type: RssBuilder::Enclosure.guess_content_type_from_url(abs_url, default: 'image/jpeg')
            }
          end
        end
      end

      # Extracts media enclosures (video/audio) from HTML tags.
      class Media
        # @param article_tag [Nokogiri::XML::Element] article container node
        # @param base_url [String, Html2rss::Url] base URL for relative media sources
        # @return [Array<Hash{Symbol => Object}>] media enclosure hashes
        def self.call(article_tag, base_url:)
          article_tag.css('video source[src], audio source[src], audio[src]').filter_map do |element|
            src = element['src'].to_s
            next if src.empty?

            {
              url: Url.from_relative(src, base_url),
              type: element['type']
            }
          end
        end
      end

      # Extracts PDF enclosures from HTML tags.
      class Pdf
        # @param article_tag [Nokogiri::XML::Element] article container node
        # @param base_url [String, Html2rss::Url] base URL for relative PDF links
        # @return [Array<Hash{Symbol => Object}>] PDF enclosure hashes
        def self.call(article_tag, base_url:)
          article_tag.css('a[href$=".pdf"]').filter_map do |link|
            href = link['href'].to_s
            next if href.empty?

            abs_url = Url.from_relative(href, base_url)
            {
              url: abs_url,
              type: RssBuilder::Enclosure.guess_content_type_from_url(abs_url)
            }
          end
        end
      end

      # Extracts iframe enclosures from HTML tags.
      class Iframe
        # @param article_tag [Nokogiri::XML::Element] article container node
        # @param base_url [String, Html2rss::Url] base URL for relative iframe links
        # @return [Array<Hash{Symbol => Object}>] iframe enclosure hashes
        def self.call(article_tag, base_url:)
          article_tag.css('iframe[src]').filter_map do |iframe|
            src = iframe['src']
            next if src.nil? || src.empty?

            abs_url = Url.from_relative(src, base_url)
            {
              url: abs_url,
              type: RssBuilder::Enclosure.guess_content_type_from_url(abs_url, default: 'text/html')
            }
          end
        end
      end

      # Extracts archive enclosures (zip, tar.gz, tgz) from HTML tags.
      class Archive
        # @param article_tag [Nokogiri::XML::Element] article container node
        # @param base_url [String, Html2rss::Url] base URL for relative archive links
        # @return [Array<Hash{Symbol => Object}>] archive enclosure hashes
        def self.call(article_tag, base_url:)
          article_tag.css('a[href$=".zip"], a[href$=".tar.gz"], a[href$=".tgz"]').filter_map do |link|
            href = link['href'].to_s
            next if href.empty?

            abs_url = Url.from_relative(href, base_url)
            {
              url: abs_url,
              type: 'application/zip'
            }
          end
        end
      end
    end
  end
end
