# frozen_string_literal: true

require 'cgi'

module Html2rss
  module Rendering
    # Renders an HTML <video> tag from a URL and type.
    class VideoRenderer
      # @param url [String, Html2rss::Url] media URL for the video source
      # @param type [String] MIME type for the video source
      def initialize(url:, type:)
        @url = url
        @type = type
      end

      # @return [String] HTML video snippet for article rendering
      def to_html
        [
          '<video controls preload="none" referrerpolicy="no-referrer" crossorigin="anonymous" playsinline>',
          %(<source src="#{escaped_url}" type="#{escaped_type}">),
          '</video>'
        ].join
      end

      private

      def escaped_url
        CGI.escapeHTML(@url.to_s)
      end

      def escaped_type
        CGI.escapeHTML(@type.to_s)
      end
    end
  end
end
