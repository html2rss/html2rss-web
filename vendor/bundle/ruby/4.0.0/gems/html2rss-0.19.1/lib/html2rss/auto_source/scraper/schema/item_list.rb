# frozen_string_literal: true

module Html2rss
  class AutoSource
    module Scraper
      class Schema
        ##
        # Handles schema.org ItemList objects, which contain
        # 1. itemListElements, and/or
        # 2. interesting attributes, i.e. description, url, image, itself.
        #
        # @see https://schema.org/ItemList
        class ItemList < Thing
          # Schema.org type names handled by the ItemList extractor.
          SUPPORTED_TYPES = Set['ItemList']

          # @return [Array<Hash>] the scraped article hashes with DEFAULT_ATTRIBUTES
          def call
            hashes = [super]

            return hashes unless (elements = @schema_object[:itemListElement])

            elements = [elements] unless elements.is_a?(Array)

            elements.each do |schema_object|
              hashes << ListItem.new(schema_object, url: base_url || '').call
            end

            hashes
          end
        end
      end
    end
  end
end
