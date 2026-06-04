# frozen_string_literal: true

module Html2rss
  class Config
    ##
    # Builds the exported configuration JSON Schema from the runtime validators.
    module Schema
      module_function

      # Canonical filename for the exported config JSON schema artifact.
      SCHEMA_FILENAME = 'html2rss-config.schema.json'

      ##
      # Returns the exported configuration JSON Schema.
      #
      # @return [Hash{String => Object}] JSON Schema represented as a Ruby hash
      def json_schema
        load_json_schema_extension!
        Builder.call
      end

      ##
      # Resolves the packaged schema path used by downstream tools.
      #
      # @return [String] absolute path to the packaged JSON schema file
      def path
        search_path = File.expand_path(__dir__)

        loop do
          candidate = File.join(search_path, 'schema', SCHEMA_FILENAME)
          return candidate if File.exist?(candidate)

          parent_path = File.dirname(search_path)
          break if parent_path == search_path

          search_path = parent_path
        end

        File.expand_path("../../../schema/#{SCHEMA_FILENAME}", __dir__)
      end

      # @return [void]
      def load_json_schema_extension!
        require 'dry/schema/extensions/json_schema'
        Dry::Schema.load_extensions(:json_schema)
      end

      ##
      # Orchestrates schema assembly from runtime validator contracts plus
      # client-facing overlays.
      class Builder
        class << self
          # @return [Hash{String => Object}] fully assembled JSON schema hash
          def call
            new.call
          end
        end

        # @return [Hash{String => Object}] fully assembled JSON schema hash
        def call
          schema = validator_schema
          apply_top_level(schema)
          assign_properties(schema.fetch(:properties))
          DeepStringifier.call(schema)
        end

        private

        def validator_schema
          Html2rss::Config::Validator.new.schema.json_schema(loose: true)
        end

        def apply_top_level(schema)
          schema['$schema'] = 'https://json-schema.org/draft/2020-12/schema'
          schema[:anyOf] = [
            { 'required' => ['selectors'] },
            { 'required' => ['auto_source'] }
          ]
        end

        def assign_properties(properties)
          properties.merge!(
            strategy: Components.strategy,
            headers: Components.headers,
            stylesheets: Components.stylesheets,
            auto_source: Components.auto_source,
            selectors: Components.selectors
          )
          properties.delete(:dynamic_params_error)
        end
      end

      ##
      # Exposes schema fragments that populate the top-level configuration schema.
      module Components
        module_function

        # @return [Hash{Symbol => Object}] schema fragment for strategy selection
        def strategy
          {
            type: 'string',
            not: { type: 'null' }
          }
        end

        # @return [Hash{Symbol => Object}] schema fragment for headers
        def headers
          {
            type: 'object',
            description: 'HTTP headers applied to every request.',
            additionalProperties: { type: 'string' }
          }
        end

        # @return [Hash{Symbol => Object}] schema fragment for stylesheet definitions
        def stylesheets
          {
            type: 'array',
            description: 'Collection of stylesheets to attach to the RSS feed.',
            items: Html2rss::Config::Validator::StylesheetConfig.json_schema(loose: true)
          }
        end

        # @return [Hash{Symbol => Object}] schema fragment for auto_source configuration
        def auto_source
          schema = Html2rss::AutoSource::Config.json_schema(loose: true)
          schema[:default] = DeepStringifier.call(Html2rss::AutoSource::DEFAULT_CONFIG)
          schema
        end

        # @return [Hash{Symbol => Object}] schema fragment for selectors configuration
        def selectors
          Selectors.schema
        end
      end

      ##
      # Provides schema fragments that document selector configuration.
      module Selectors
        module_function

        # Pattern used for dynamic selector keys excluding reserved selector names.
        RESERVED_SELECTOR_PATTERN = '^(?!items$|enclosure$|guid$|categories$).+$'

        # @return [Hash{Symbol => Object}] schema fragment for selectors root object
        def schema
          {
            type: 'object',
            description: 'Selectors used to extract article attributes.',
            properties: selector_properties,
            patternProperties: pattern_properties,
            additionalProperties: true
          }
        end

        # rubocop:disable Layout/LineLength
        # @return [Hash{Symbol => Object}] schema map for reserved selector properties
        def selector_properties
          {
            items: items_schema,
            enclosure: enclosure_schema,
            guid: reference_array('List of selector keys used to build the GUID. Each entry must reference a sibling selector key; runtime validation enforces those references.'),
            categories: reference_array('List of selector keys whose values will be used as categories. Each entry must reference a sibling selector key; runtime validation enforces those references.')
          }
        end
        # rubocop:enable Layout/LineLength

        # @return [Hash{String => Object}] schema map for dynamic selector keys
        def pattern_properties
          { RESERVED_SELECTOR_PATTERN => dynamic_selector_schema }
        end

        # @return [Hash{Symbol => Object}] schema fragment for dynamic selector entries
        def dynamic_selector_schema
          Html2rss::Selectors::Config::Selector.new.schema.json_schema(loose: true).merge(
            description: 'Dynamic selector definition keyed by attribute name.'
          )
        end

        # @return [Hash{Symbol => Object}] schema fragment for `items` selector configuration
        def items_schema
          Html2rss::Selectors::Config::Items.new.schema.json_schema(loose: true).merge(
            description: 'Defines the items selector and optional enhancement settings.'
          )
        end

        # @return [Hash{Symbol => Object}] schema fragment for `enclosure` selector configuration
        def enclosure_schema
          Html2rss::Selectors::Config::Enclosure.new.schema.json_schema(loose: true).merge(
            description: 'Describes enclosure extraction settings.'
          )
        end

        # JSON Schema can enforce non-empty reference arrays, while runtime
        # validation remains authoritative for checking that each entry points
        # to an existing sibling selector key.
        # @param description [String] human-readable description for the reference field
        # @return [Hash{Symbol => Object}] JSON schema fragment for selector references
        def reference_array(description)
          {
            type: 'array',
            description:,
            minItems: 1,
            items: {
              type: 'string',
              description: 'Selector key defined elsewhere in this object.'
            }
          }
        end
      end

      ##
      # Converts nested hash keys to strings so the resulting schema serializes cleanly.
      module DeepStringifier
        module_function

        # @param object [Hash, Array, Object] nested data to normalize
        # @return [Hash, Array, Object] deep copy with stringified hash keys
        def call(object)
          case object
          when Hash
            stringify_hash(object)
          when Array
            object.map { |value| call(value) }
          when Symbol
            object.to_s
          else
            object
          end
        end

        # @param object [Hash{Object => Object}] hash whose keys should become strings
        # @return [Hash{String => Object}] hash with recursively normalized values
        def stringify_hash(object)
          object.to_h { |key, value| [key.to_s, call(value)] }
        end
      end
    end
  end
end
