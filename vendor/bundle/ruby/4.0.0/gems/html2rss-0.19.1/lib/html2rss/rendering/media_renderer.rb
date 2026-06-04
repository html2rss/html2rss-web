# frozen_string_literal: true

module Html2rss
  module Rendering
    # Factory: picks the appropriate renderer for a given enclosure or fallback image.
    class MediaRenderer
      # @param enclosure [Html2rss::RssBuilder::Enclosure, nil]
      # @param image [String, Html2rss::Url, nil] Fallback image URL
      # @param title [String]
      # @return [ImageRenderer, VideoRenderer, AudioRenderer, PdfRenderer, nil]
      def self.for(enclosure:, image:, title:)
        return ImageRenderer.new(url: image, title:) if enclosure.nil? && image
        return nil unless enclosure

        create_renderer_for_type(enclosure.type, url: enclosure.url, title:)
      end

      # @private
      # @param type [String, nil] enclosure MIME type
      # @param url [String, Html2rss::Url] enclosure URL
      # @param title [String, nil] title used by image renderer
      # @return [ImageRenderer, VideoRenderer, AudioRenderer, PdfRenderer, nil]
      def self.create_renderer_for_type(type, url:, title:)
        case type
        when %r{^image/}
          ImageRenderer.new(url:, title:)
        when %r{^video/}
          VideoRenderer.new(url:, type:)
        when %r{^audio/}
          AudioRenderer.new(url:, type:)
        when 'application/pdf'
          PdfRenderer.new(url:)
        end
      end
    end
  end
end
