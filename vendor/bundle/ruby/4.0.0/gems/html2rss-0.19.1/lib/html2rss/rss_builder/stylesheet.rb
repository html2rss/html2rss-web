# frozen_string_literal: true

module Html2rss
  class RssBuilder
    ##
    # Represents a stylesheet.
    class Stylesheet
      class << self
        ##
        # Adds the stylesheet XML tags to the RSS.
        #
        # @param maker [RSS::Maker::RSS20] RSS maker object.
        # @param stylesheets [Array<Html2rss::RssBuilder::Stylesheet>] Array of stylesheet configurations.
        # @return [nil]
        def add(maker, stylesheets)
          stylesheets.each do |stylesheet|
            add_stylesheet(maker, stylesheet)
          end
        end

        private

        ##
        # Adds a single Stylesheet to the RSS.
        #
        # @param maker [RSS::Maker::RSS20] RSS maker object.
        # @param stylesheet [Html2rss::RssBuilder::Stylesheet] Stylesheet configuration.
        # @return [nil]
        def add_stylesheet(maker, stylesheet)
          maker.xml_stylesheets.new_xml_stylesheet do |xss|
            xss.href = stylesheet.href
            xss.type = stylesheet.type
            xss.media = stylesheet.media
          end
        end
      end

      # Allowed stylesheet MIME types for RSS processing instructions.
      TYPES = ['text/css', 'text/xsl'].to_set.freeze

      # @param href [String] stylesheet URL
      # @param type [String] MIME type (`text/css` or `text/xsl`)
      # @param media [String] media query hint for the stylesheet
      def initialize(href:, type:, media: 'all')
        raise ArgumentError, 'stylesheet.href must be a String' unless href.is_a?(String)
        raise ArgumentError, 'stylesheet.type invalid' unless TYPES.include?(type)
        raise ArgumentError, 'stylesheet.media must be a String' unless media.is_a?(String)

        @href = href
        @type = type
        @media = media
      end
      attr_reader :href, :type, :media

      # @return [String] the XML representation of the stylesheet
      def to_xml
        <<~XML
          <?xml-stylesheet href="#{href}" type="#{type}" media="#{media}"?>
        XML
      end
    end
  end
end
