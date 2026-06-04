# frozen_string_literal: true

module Html2rss
  class AutoSource
    module Scraper
      # Scrapes Schema.org Microdata items embedded directly in HTML markup.
      class Microdata
        include Enumerable

        # Selector matching nodes that define a microdata item scope.
        ITEM_SELECTOR = '[itemscope][itemtype]'
        # Schema.org types supported for article extraction via Microdata.
        SUPPORTED_TYPES = (Schema::Thing::SUPPORTED_TYPES | Set['Product']).freeze
        # Attribute names checked first for microdata property values.
        VALUE_ATTRIBUTES = %w[content datetime href src data value].freeze

        # @return [Symbol] scraper config key
        def self.options_key = :microdata

        class << self
          # @param parsed_body [Nokogiri::HTML::Document, nil] parsed HTML document
          def articles?(parsed_body)
            supported_roots(parsed_body).any?
          end

          # @param parsed_body [Nokogiri::HTML::Document, nil] parsed HTML document
          # @return [Array<Nokogiri::XML::Element>] top-level supported Microdata roots
          def supported_roots(parsed_body)
            return [] unless parsed_body

            parsed_body.css(ITEM_SELECTOR).select { supported_root?(_1) }
          end

          # @param node [Nokogiri::XML::Element] itemscope candidate node
          def supported_root?(node)
            supported_type_name(node) && top_level_item?(node)
          end

          # @param node [Nokogiri::XML::Element] itemscope candidate node
          # @return [String, nil] supported schema type name when present
          def supported_type_name(node)
            normalized_types(node['itemtype']).find { SUPPORTED_TYPES.include?(_1) }
          end

          # @param itemtype [String, nil] raw itemtype attribute value
          # @return [Array<String>] normalized schema type names
          def normalized_types(itemtype)
            itemtype.to_s.split.filter_map do |value|
              type = value.split('/').last.to_s.split('#').last.to_s
              type unless type.empty?
            end
          end

          # @param node [Nokogiri::XML::Element] itemscope candidate node
          def top_level_item?(node)
            return false if node.attribute('itemprop')

            node.ancestors.none? { |ancestor| ancestor.attribute('itemscope') && ancestor.attribute('itemprop') }
          end
        end

        ##
        # Builds a Microdata scraper for an already parsed response body.
        #
        # @param parsed_body [Nokogiri::HTML5::Document, Nokogiri::HTML4::Document, Nokogiri::XML::Node, nil]
        #   the parsed response body to inspect for top-level Microdata items.
        # @param url [Html2rss::Url] the absolute page URL used to resolve relative links.
        # @param _opts [Hash] unused scraper-specific options.
        # @option _opts [Object] :_reserved reserved for future scraper-specific options
        # @return [void]
        def initialize(parsed_body, url:, **_opts)
          @parsed_body = parsed_body
          @url = url
        end

        ##
        # Iterates over normalized article hashes extracted from supported Microdata roots.
        #
        # @yieldparam article [Hash{Symbol => Object}] the normalized article attributes.
        # @return [Enumerator, void] an enumerator when no block is given.
        def each
          return enum_for(:each) unless block_given?

          self.class.supported_roots(parsed_body).each do |root|
            article = article_from(root)
            yield article if article
          end
        end

        private

        attr_reader :parsed_body, :url

        # @param root [Nokogiri::XML::Element] supported Microdata root node
        # @return [Hash{Symbol => Object}, nil] normalized article hash
        def article_from(root)
          schema_object = SchemaObjectBuilder.call(root)
          return unless schema_object

          article = Schema::Thing.new(schema_object, url:).call.compact
          return unless valid_article?(article)

          article
        end

        # @param article [Hash{Symbol => Object}] normalized article hash
        # @return [Boolean] whether article contains required fields
        def valid_article?(article)
          return false unless article[:url]

          article[:title] || article[:description]
        end

        # Extracts direct Microdata itemprop values for a single item root.
        module ItemParser
          module_function

          # @param root [Nokogiri::XML::Element] microdata root node
          # @return [Hash{Symbol => Object}] extracted direct properties
          def call(root)
            {}.tap do |properties|
              direct_properties(root).each { append_properties!(properties, _1) }
            end
          end

          # @param properties [Hash{Symbol => Object}] accumulator hash for parsed properties
          # @param node [Nokogiri::XML::Element] itemprop node
          # @return [void]
          def append_properties!(properties, node)
            value = property_value(node)
            return if blank_value?(value)

            property_names(node).each do |name|
              append(properties, name.to_sym, value)
            end
          end

          # @param root [Nokogiri::XML::Element] microdata root node
          # @return [Array<Nokogiri::XML::Element>] direct property nodes for the root
          def direct_properties(root)
            root.css('[itemprop]').select { direct_property?(root, _1) }
          end

          # @param root [Nokogiri::XML::Element] microdata root node
          # @param node [Nokogiri::XML::Element] candidate itemprop node
          # @return [Boolean] whether the node belongs directly to the current root item
          def direct_property?(root, node)
            return false if node == root

            node.ancestors.take_while { _1 != root }.none? { |ancestor| ancestor.attribute('itemscope') }
          end

          # @param node [Nokogiri::XML::Element] itemprop node
          # @return [Array<String>] normalized property names
          def property_names(node)
            node['itemprop'].to_s.split.filter_map do |name|
              stripped = name.strip
              stripped unless stripped.empty?
            end
          end

          # @param node [Nokogiri::XML::Element] itemprop node
          # @return [Object, nil] parsed property value
          def property_value(node)
            value = if node.attribute('itemscope')
                      nested_item(node)
                    else
                      attribute_value(node) || text_value(node)
                    end

            value unless blank_value?(value)
          end

          # @param node [Nokogiri::XML::Element] nested itemscope node
          # @return [Hash{Symbol => Object}] nested parsed microdata item
          def nested_item(node)
            item = call(node)
            itemtype = node['itemtype']
            itemid = node['itemid']
            item[:@type] = Microdata.normalized_types(itemtype).first if itemtype
            item[:@id] = itemid if present?(itemid)
            item
          end

          # @param node [Nokogiri::XML::Element] itemprop node
          # @return [String, nil] first present attribute value
          def attribute_value(node)
            VALUE_ATTRIBUTES.each do |attribute|
              value = node[attribute]
              return value if present?(value)
            end

            nil
          end

          # @param node [Nokogiri::XML::Element] itemprop node
          # @return [String, nil] normalized text content
          def text_value(node)
            value = node.text.to_s.strip
            value unless value.empty?
          end

          # @param properties [Hash{Symbol => Object}] accumulator hash for parsed properties
          # @param key [Symbol] target property key
          # @param value [Object] parsed property value to assign for the key
          # @return [void]
          def append(properties, key, value)
            return if blank_value?(value)

            unless properties.key?(key)
              properties[key] = value
              return
            end

            properties[key] = Array(properties[key]) << value
          end

          # @param value [Object] candidate value
          # @return [Boolean] whether value is blank for microdata extraction purposes
          def blank_value?(value)
            case value
            when nil then true
            when String then value.strip.empty?
            when Array, Hash then value.empty?
            else false
            end
          end

          # @param value [Object] candidate value
          # @return [Boolean] whether value is present for microdata extraction purposes
          def present?(value)
            !blank_value?(value)
          end
        end
        private_constant :ItemParser

        # Shared value normalization helpers for Microdata property conversion.
        module ValueNormalizer
          module_function

          # @param values [Array<Object>] value candidates
          # @return [String, nil] first URL-like value converted to string
          def url_value(*values)
            values.each do |value|
              candidate = extract_nested_value(value, :url, :@id)
              return candidate.to_s if present?(candidate)
            end

            nil
          end

          # @param values [Array<Object>] value candidates
          # @return [String, Hash, nil] first normalized image candidate
          def image_value(*values)
            values.each do |value|
              candidate = normalize_image(value)
              return candidate if present?(candidate)
            end

            nil
          end

          # @param value [Object] image candidate value
          # @return [String, Hash, nil] normalized image-like value
          def normalize_image(value)
            candidate = unwrap(value)
            return unless present?(candidate)

            return candidate if candidate.is_a?(String) || candidate.is_a?(Hash)

            candidate.to_s
          end

          # @param value [Object] about candidate value
          # @return [Array<String, Hash>, nil] normalized about values
          def normalize_about(value)
            candidate = unwrap(value)
            items = candidate.is_a?(Array) ? candidate : [candidate]
            values = items.filter_map { normalize_about_item(_1) }
            values unless values.empty?
          end

          # @param item [Object] single about item
          # @return [String, Hash, nil] normalized about item
          def normalize_about_item(item)
            case item
            when Hash
              name = item[:name]
              { name: name.to_s } if name
            when String then item
            end
          end

          # @param value [Object] scalar or array candidate
          # @return [String, Array<String>, nil] normalized scalar or string array
          def string_or_array(value)
            candidate = unwrap(value)
            return unless present?(candidate)

            return stringify(candidate) unless candidate.is_a?(Array)

            result = string_values(candidate)
            result unless result.empty?
          end

          # @param values [Array<Object>] value candidates
          # @return [Array<String>, nil] normalized unique string values
          def array_value(*values)
            result = values.flat_map { string_values(Array(unwrap(_1))) }.uniq
            result unless result.empty?
          end

          # @param values [Array<Object>] candidate scalar values collected from microdata arrays
          # @return [Array<String>] normalized string values
          def string_values(values)
            values.filter_map { stringify(_1) }
          end

          # @param values [Array<Object>] value candidates
          # @return [String, nil] first present string-like value
          def first_string(*values)
            values.each do |value|
              candidate = stringify(unwrap(value))
              return candidate if present?(candidate)
            end

            nil
          end

          # @param value [Object] nested container or scalar
          # @param keys [Array<Symbol>] nested keys to probe in order
          # @return [Object, nil] first matching nested value
          def extract_nested_value(value, *keys)
            candidate = unwrap(value)
            return candidate unless candidate.is_a?(Hash)

            keys.each do |key|
              nested_value = candidate[key]
              return nested_value if present?(nested_value)
            end

            nil
          end

          # @param value [Object] scalar or array candidate
          # @return [Object] first array element or the original value
          def unwrap(value)
            value.is_a?(Array) ? value.first : value
          end

          # @param value [Object] scalar candidate normalized to string output
          # @return [String, nil] normalized string representation
          def stringify(value)
            return unless present?(value)
            return value if value.is_a?(String)
            return if value.is_a?(Hash) || value.is_a?(Array)

            value.to_s
          end

          # @param value [Object] candidate value
          # @return [Boolean] whether value is present
          def present?(value)
            case value
            when nil then false
            when String then !value.strip.empty?
            when Array, Hash then !value.empty?
            else true
            end
          end
        end
        private_constant :ValueNormalizer

        # Normalizes raw Microdata properties into the schema-like shape used downstream.
        module SchemaObjectBuilder
          module_function

          extend ValueNormalizer

          # @param root [Nokogiri::XML::Element] supported microdata root node
          # @return [Hash{Symbol => Object}, nil] compact schema-like object
          def call(root)
            type = Microdata.supported_type_name(root)
            return unless type

            compact_object(type, root, ItemParser.call(root))
          end

          # @param type [String] schema type inferred from itemtype
          # @param root [Nokogiri::XML::Element] supported microdata root node
          # @param properties [Hash{Symbol => Object}] parsed microdata properties
          # @return [Hash{Symbol => Object}] normalized schema-like object
          def compact_object(type, root, properties)
            object = base_attributes(type, root, properties)
            merge_categories!(object, properties)
            object.compact
          end

          # @param type [String] schema type inferred from itemtype
          # @param root [Nokogiri::XML::Element] supported microdata root node
          # @param properties [Hash{Symbol => Object}] parsed microdata properties
          # @return [Hash{Symbol => Object}] base schema attributes before category merging
          def base_attributes(type, root, properties)
            identifier = first_string(root['itemid'], properties.delete(:identifier))

            {
              '@type': type,
              '@id': identifier
            }.merge(text_attributes(properties))
              .merge(link_attributes(properties, identifier))
              .merge(media_attributes(properties))
          end

          # @param properties [Hash{Symbol => Object}] parsed microdata properties
          # @return [String, nil] normalized title
          def title(properties)
            first_string(properties.delete(:headline), properties.delete(:title), properties.delete(:name))
          end

          # @param properties [Hash{Symbol => Object}] parsed microdata properties
          # @return [Hash{Symbol => Object}] normalized text attributes
          def text_attributes(properties)
            {
              title: title(properties),
              description: first_string(properties.delete(:description)),
              schema_object_body: first_string(properties.delete(:articleBody)),
              abstract: first_string(properties.delete(:abstract)),
              datePublished: published_at(properties)
            }
          end

          # @param properties [Hash{Symbol => Object}] parsed microdata properties
          # @param identifier [String, nil] identifier candidate for fallback URL handling
          # @return [Hash{Symbol => Object}] normalized link attributes
          def link_attributes(properties, identifier)
            {
              url: url(properties, identifier)
            }
          end

          # @param properties [Hash{Symbol => Object}] parsed microdata properties
          # @return [Hash{Symbol => Object}] normalized media attributes
          def media_attributes(properties)
            {
              image: image_value(properties.delete(:image), properties.delete(:thumbnailUrl))
            }
          end

          # @param properties [Hash{Symbol => Object}] parsed microdata properties
          # @param fallback_id [String, nil] identifier candidate for fallback URL handling
          # @return [String, nil] normalized URL candidate
          def url(properties, fallback_id)
            url_value(
              properties.delete(:url),
              properties.delete(:mainEntityOfPage),
              url_fallback(fallback_id)
            )
          end

          # @param fallback_id [String, nil] identifier candidate for fallback URL handling
          # @return [String, nil] fallback URL candidate when identifier looks URL-like
          def url_fallback(fallback_id)
            value = first_string(fallback_id)
            return unless value
            return value if value.start_with?('/')
            return value if value.match?(%r{\Ahttps?://})

            nil
          end

          # @param properties [Hash{Symbol => Object}] parsed microdata properties
          # @return [String, nil] normalized published-at value
          def published_at(properties)
            first_string(
              properties.delete(:datePublished),
              properties.delete(:dateCreated),
              properties.delete(:dateModified),
              properties.delete(:uploadDate)
            )
          end

          # @param object [Hash{Symbol => Object}] schema-like output object
          # @param properties [Hash{Symbol => Object}] parsed microdata properties
          # @return [void]
          def merge_categories!(object, properties)
            categories = array_value(properties.delete(:categories), properties.delete(:articleSection))
            assign_if_present(object, :categories, categories)
            assign_if_present(object, :keywords, string_or_array(properties.delete(:keywords)))
            assign_if_present(object, :tags, string_or_array(properties.delete(:tags)))
            assign_if_present(object, :about, normalize_about(properties.delete(:about)))
          end

          # @param object [Hash{Symbol => Object}] schema-like output object
          # @param key [Symbol] target attribute key
          # @param value [Object] value to assign when present
          # @return [void]
          def assign_if_present(object, key, value)
            object[key] = value if value
          end
        end
        private_constant :SchemaObjectBuilder
      end
    end
  end
end
