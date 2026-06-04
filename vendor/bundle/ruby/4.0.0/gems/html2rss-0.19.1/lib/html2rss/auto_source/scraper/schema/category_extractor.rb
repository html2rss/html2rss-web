# frozen_string_literal: true

module Html2rss
  class AutoSource
    module Scraper
      class Schema
        ##
        # Extracts categories from Schema.org structured data.
        module CategoryExtractor
          ##
          # Extracts categories from a schema object.
          #
          # @param schema_object [Hash] The schema object
          # @return [Array<String>] Array of category strings
          def self.call(schema_object)
            # Build union of all category sources
            field_categories = extract_field_categories(schema_object)
            about_categories = extract_about_categories(schema_object)

            (field_categories | about_categories).to_a
          end

          ##
          # Extracts categories from keywords, categories, and tags fields.
          #
          # @param schema_object [Hash] The schema object
          # @return [Set<String>] Set of category strings
          def self.extract_field_categories(schema_object)
            Set.new.tap do |categories|
              %w[keywords categories tags].each do |field|
                categories.merge(extract_field_value(schema_object, field))
              end
            end
          end

          ##
          # Extracts categories from the about field.
          #
          # @param schema_object [Hash] The schema object
          # @return [Set<String>] Set of category strings
          def self.extract_about_categories(schema_object)
            about = schema_object[:about]
            return Set.new unless about

            if about.is_a?(Array)
              extract_about_array(about)
            elsif about.is_a?(String)
              extract_string_categories(about)
            else
              Set.new
            end
          end

          ##
          # Extracts categories from a single field value.
          #
          # @param schema_object [Hash] The schema object
          # @param field [String] The field name
          # @return [Set<String>] Set of category strings
          def self.extract_field_value(schema_object, field)
            value = schema_object[field.to_sym]
            return Set.new unless value

            if value.is_a?(Array)
              Set.new(value.map(&:to_s).reject(&:empty?))
            elsif value.is_a?(String)
              extract_string_categories(value)
            else
              Set.new
            end
          end

          ##
          # Extracts categories from an about array.
          #
          # @param about [Array] The about array
          # @return [Set<String>] Set of category strings
          def self.extract_about_array(about)
            Set.new.tap do |categories|
              about.each do |item|
                if item.is_a?(Hash) && item[:name]
                  categories.add(item[:name].to_s)
                elsif item.is_a?(String)
                  categories.add(item)
                end
              end
            end
          end

          ##
          # Extracts categories from a string by splitting on separators.
          #
          # @param string [String] source string that may contain category delimiters
          # @return [Set<String>] Set of category strings
          def self.extract_string_categories(string)
            Set.new(string.split(/[,;|]/).map(&:strip).reject(&:empty?))
          end
        end
      end
    end
  end
end
