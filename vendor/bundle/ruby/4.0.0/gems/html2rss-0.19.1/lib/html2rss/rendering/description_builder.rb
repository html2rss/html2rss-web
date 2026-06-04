# frozen_string_literal: true

module Html2rss
  module Rendering
    # Builds a sanitized article description from the base text, title, and optional media.
    #
    # Combines media elements (images, audio, video, PDFs) with sanitized text content
    # to create rich RSS descriptions that reveal more scraped information.
    #
    # @example Basic usage
    #   builder = DescriptionBuilder.new(
    #     base: "Article content",
    #     title: "Article Title",
    #     url: "https://example.com",
    #     enclosures: [enclosure_object],
    #     image: "https://example.com/image.jpg"
    #   )
    #   description = builder.call
    class DescriptionBuilder
      # Removes the specified pattern from the beginning of the text
      # within a given range if the pattern occurs before the range's end.
      #
      # @param text [String]
      # @param pattern [String]
      # @param end_of_range [Integer] Optional, defaults to half the text length
      # @return [String]
      def self.remove_pattern_from_start(text, pattern, end_of_range: (text.size * 0.5).to_i)
        return text unless text.is_a?(String) && pattern.is_a?(String)

        index = text.index(pattern)
        return text if index.nil? || index >= end_of_range

        text.gsub(/^(.{0,#{end_of_range}})#{Regexp.escape(pattern)}/, '\1')
      end

      # @param base [String] The base text content for the description
      # @param title [String] The article title (used for alt text and title removal)
      # @param url [String, Html2rss::Url] The article URL (used for sanitization)
      # @param enclosures [Array<Html2rss::RssBuilder::Enclosure>, nil] Media enclosures
      # @param image [String, Html2rss::Url, nil] Fallback image URL
      def initialize(base:, title:, url:, enclosures:, image:)
        @base = base.to_s
        @title = title
        @url = url
        @enclosures = Array(enclosures)
        @image = image
      end

      # Generates the complete description with media and sanitized text.
      #
      # @return [String, nil] The complete description or nil if empty
      def call
        fragments = []
        fragments.concat(Array(rendered_media))
        fragments << processed_base_description

        result = fragments.compact.join("\n\n").strip
        result.empty? ? nil : result
      end

      private

      def rendered_media
        rendered = render_enclosures
        return rendered if rendered.any?
        return render_fallback_image if @image

        []
      end

      def render_enclosures
        @enclosures.filter_map do |enclosure|
          MediaRenderer.for(enclosure:, image: @image, title: @title)&.to_html
        end
      end

      def render_fallback_image
        [MediaRenderer.for(enclosure: nil, image: @image, title: @title)&.to_html]
      end

      def processed_base_description
        text = self.class.remove_pattern_from_start(@base, @title)
        Html2rss::Selectors::PostProcessors::SanitizeHtml.get(text, @url)
      end
    end
  end
end
