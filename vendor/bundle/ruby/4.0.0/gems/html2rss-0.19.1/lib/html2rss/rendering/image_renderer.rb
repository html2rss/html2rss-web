# frozen_string_literal: true

require 'cgi'

module Html2rss
  module Rendering
    # Renders an HTML <img> tag from a URL and title.
    class ImageRenderer
      # @param url [String, Html2rss::Url] image URL for the src attribute
      # @param title [String, nil] title/alt text for the image
      def initialize(url:, title:)
        @url = url
        @title = title
      end

      # @return [String] HTML image snippet for article rendering
      def to_html
        attributes = [
          %(src="#{escaped_url}"),
          %(alt="#{escaped_title}"),
          %(title="#{escaped_title}"),
          'loading="lazy"',
          'referrerpolicy="no-referrer"',
          'decoding="async"',
          'crossorigin="anonymous"'
        ]
        "<img #{attributes.join(' ')}>"
      end

      private

      def escaped_url
        CGI.escapeHTML(@url.to_s)
      end

      def escaped_title
        CGI.escapeHTML(@title.to_s)
      end
    end
  end
end
