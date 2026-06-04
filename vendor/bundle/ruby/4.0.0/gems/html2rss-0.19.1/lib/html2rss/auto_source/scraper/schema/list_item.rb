# frozen_string_literal: true

module Html2rss
  class AutoSource
    module Scraper
      class Schema
        ##
        # @see https://schema.org/ListItem
        class ListItem < Thing
          # @return [String, nil] stable list-item identifier
          def id =          (id = (schema_object.dig(:item, :@id) || super).to_s).empty? ? nil : id
          # @return [String, nil] list-item title
          def title =       schema_object.dig(:item, :name) || super || url&.titleized
          # @return [String, nil] list-item description
          def description = schema_object.dig(:item, :description) || super

          # @return [Html2rss::Url, nil]
          def url
            url = schema_object.dig(:item, :url) || super

            Url.from_relative(url, base_url || url) if url
          end
        end
      end
    end
  end
end
