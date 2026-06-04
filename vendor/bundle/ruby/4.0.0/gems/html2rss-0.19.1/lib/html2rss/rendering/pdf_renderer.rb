# frozen_string_literal: true

require 'cgi'

module Html2rss
  module Rendering
    # Renders an HTML <iframe> for PDF documents.
    class PdfRenderer
      # @param url [String, Html2rss::Url] PDF URL rendered in the iframe
      def initialize(url:)
        @url = url
      end

      # @return [String] HTML iframe snippet for PDF rendering
      def to_html
        attributes = [
          %(src="#{escaped_url}"),
          'width="100%"',
          'height="75vh"',
          'sandbox=""',
          'referrerpolicy="no-referrer"',
          'loading="lazy"'
        ]
        "<iframe #{attributes.join(' ')}></iframe>"
      end

      private

      def escaped_url
        CGI.escapeHTML(@url.to_s)
      end
    end
  end
end
