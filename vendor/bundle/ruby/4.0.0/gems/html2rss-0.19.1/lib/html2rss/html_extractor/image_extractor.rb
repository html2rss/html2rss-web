# frozen_string_literal: true

module Html2rss
  class HtmlExtractor
    ##
    # Image is responsible for extracting image URLs the article_tag.
    class ImageExtractor
      # @param article_tag [Nokogiri::XML::Element] article container node
      # @param base_url [String, Html2rss::Url] base URL for relative image URLs
      # @return [Html2rss::Url, nil] best candidate image URL
      def self.call(article_tag, base_url:)
        img_src = from_source(article_tag) ||
                  from_img(article_tag) ||
                  from_style(article_tag)

        Url.from_relative(img_src, base_url) if img_src
      end

      # @param article_tag [Nokogiri::XML::Element] article container node
      # @return [String, nil] src attribute from first matching image tag
      def self.from_img(article_tag)
        article_tag.at_css('img[src]:not([src^="data"])')&.[]('src')
      end

      ##
      # Extracts the largest image source from the srcset attribute
      # of an img tag or a source tag inside a picture tag.
      #
      # @param article_tag [Nokogiri::XML::Element] article container node
      # @return [String, nil] largest srcset URL candidate
      # @see <https://developer.mozilla.org/en-US/docs/Learn/HTML/Multimedia_and_embedding/Responsive_images>
      # @see <https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img#srcset>
      # @see <https://developer.mozilla.org/en-US/docs/Web/HTML/Element/picture>
      def self.from_source(article_tag) # rubocop:disable Metrics/AbcSize
        hash = article_tag.css('img[srcset], picture > source[srcset]').flat_map do |source|
          source['srcset'].to_s.scan(/(\S+)\s+(\d+w|\d+h)[\s,]?/).map do |url, width|
            next if url.nil? || url.start_with?('data:')

            width_value = width.to_i.zero? ? 0 : width.scan(/\d+/).first.to_i

            [width_value, url.strip]
          end
        end.compact.to_h

        hash[hash.keys.max]
      end

      # @param article_tag [Nokogiri::XML::Element] article container node
      # @return [String, nil] best style-based background image URL
      def self.from_style(article_tag)
        article_tag.css('[style*="url"]')
                   .filter_map { |tag| tag['style'][/url\(['"]?(.*?)['"]?\)/, 1] }
                   .reject { |src| src.start_with?('data:') }
                   .max_by(&:size)
      end
    end
  end
end
