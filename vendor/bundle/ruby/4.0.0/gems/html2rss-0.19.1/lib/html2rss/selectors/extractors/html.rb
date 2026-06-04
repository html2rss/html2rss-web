# frozen_string_literal: true

module Html2rss
  class Selectors
    module Extractors
      ##
      # Returns the HTML content of the specified element.
      #
      # Example HTML structure:
      #
      #     <p>Lorem <b>ipsum</b> dolor ...</p>
      #
      # YAML usage example:
      #
      #    selectors:
      #      description:
      #        selector: p
      #        extractor: html
      #
      # Would return:
      #    '<p>Lorem <b>ipsum</b> dolor ...</p>'
      #
      # Always ensure to sanitize the HTML during post-processing with
      # {PostProcessors::SanitizeHtml}.
      class Html
        # The available options for the html extractor.
        Options = Struct.new('HtmlOptions', :selector, keyword_init: true) # rubocop:disable Style/RedundantStructKeywordInit

        ##
        # Initializes the Html extractor.
        #
        # @param xml [Nokogiri::XML::Element]
        # @param options [Options]
        # @option options [String] :selector CSS selector used to find the element
        def initialize(xml, options)
          @element = Extractors.element(xml, options.selector)
        end

        ##
        # Retrieves and returns the HTML content of the element.
        #
        # @return [String] The HTML content.
        def get
          @element.to_s
        end
      end
    end
  end
end
