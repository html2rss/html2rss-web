# frozen_string_literal: true

require 'html2rss'

##
# Lifts +Html2rss::Config::Schema.json_schema+'s selectors subtree into OpenAPI 3.1
# component schemas. One walk copies, allowlists keywords, rewrites +$ref+, and
# hoists the transitive +$defs+ closure.
module Openapi
  module JsonSchema
    ##
    # Raised when a schema node uses a keyword outside the mounted allowlist.
    class Unsupported < StandardError; end

    ROOT_NAME = 'SelectorsDocument'
    # Keywords on the mounted selectors closure, plus +exclusiveMaximum+.
    ALLOWED_KEYWORDS = %w[
      $ref $schema additionalProperties const default description enum examples
      exclusiveMaximum exclusiveMinimum items maxLength minItems minLength not
      oneOf pattern patternProperties properties required title type
    ].to_set.freeze
    MAP_APPLICATORS = %w[properties patternProperties].to_set.freeze
    SCHEMA_APPLICATORS = %w[additionalProperties items not].to_set.freeze
    ARRAY_APPLICATORS = %w[oneOf].to_set.freeze
    # Irregular $defs path segments → OpenAPI component CamelCase (no plural chomp).
    SEGMENT_CAMEL = {
      'post_processors' => 'PostProcessor',
      'extractors' => 'Extractor'
    }.freeze
    private_constant :MAP_APPLICATORS, :SCHEMA_APPLICATORS, :ARRAY_APPLICATORS, :SEGMENT_CAMEL

    class << self
      ##
      # Translates the selectors slice into OpenAPI component schemas.
      #
      # @param document [Hash] JSON Schema document; defaults to the gem schema
      # @return [Hash{String=>Hash}] component name → OpenAPI 3.1 schema object
      # @raise [Openapi::JsonSchema::Unsupported] on an unknown keyword
      def components(document = Html2rss::Config::Schema.json_schema)
        source = deep_stringify(document)
        selectors = source.dig('properties', 'selectors')
        raise Unsupported, 'missing /properties/selectors' unless selectors.is_a?(Hash)

        collected = {}
        root = translate(selectors, '/properties/selectors', source.fetch('$defs', {}), collected)
        { ROOT_NAME => root }.merge(collected.sort.to_h)
      end

      private

      # @param node [Object]
      # @param pointer [String]
      # @param defs [Hash]
      # @param collected [Hash{String=>Hash}]
      # @return [Object]
      def translate(node, pointer, defs, collected)
        case node
        in Hash then translate_object(node, pointer, defs, collected)
        in Array
          node.map.with_index { |item, i| translate(item, "#{pointer}/#{i}", defs, collected) }
        else node
        end
      end

      # @param node [Hash]
      # @param pointer [String]
      # @param defs [Hash]
      # @param collected [Hash{String=>Hash}]
      # @return [Hash]
      # rubocop:disable-next Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity -- single keyword dispatch
      def translate_object(node, pointer, defs, collected)
        node.each_with_object({}) do |(key, value), result|
          raise Unsupported, "#{pointer}/#{key}" unless ALLOWED_KEYWORDS.include?(key)
          next if key == '$schema'

          child = "#{pointer}/#{key}"
          result[key] =
            if key == '$ref'
              rewrite_ref(value, child, defs, collected)
            elsif MAP_APPLICATORS.include?(key)
              raise Unsupported, child unless value.is_a?(Hash)

              value.to_h { |n, s| [n.to_s, translate(s, "#{child}/#{n}", defs, collected)] }
            elsif SCHEMA_APPLICATORS.include?(key)
              value.is_a?(Hash) ? translate(value, child, defs, collected) : value
            elsif ARRAY_APPLICATORS.include?(key)
              raise Unsupported, child unless value.is_a?(Array)

              value.map.with_index { |s, i| translate(s, "#{child}/#{i}", defs, collected) }
            else
              deep_stringify(value)
            end
        end
      end

      # @param ref [Object]
      # @param pointer [String]
      # @param defs [Hash]
      # @param collected [Hash{String=>Hash}]
      # @return [String]
      def rewrite_ref(ref, pointer, defs, collected)
        raise Unsupported, pointer unless ref.is_a?(String) && ref.start_with?('#/$defs/')

        def_path = ref.delete_prefix('#/$defs/')
        name = component_name(def_path)
        unless collected.key?(name)
          collected[name] = translate(resolve_def(defs, def_path, pointer), "#/$defs/#{def_path}", defs, collected)
        end
        "#/components/schemas/#{name}"
      end

      # @param defs [Hash]
      # @param def_path [String]
      # @param pointer [String]
      # @return [Hash]
      def resolve_def(defs, def_path, pointer)
        body = def_path.split('/').reduce(defs) do |node, segment|
          raise Unsupported, pointer unless node.is_a?(Hash) && node.key?(segment)

          node.fetch(segment)
        end
        raise Unsupported, pointer unless body.is_a?(Hash)

        body
      end

      # @param def_path [String]
      # @return [String]
      def component_name(def_path)
        camel = def_path.split('/').map { camelize_segment(it) }.join
        name = "Html2rss#{camel}"
        raise Unsupported, "invalid component name #{name}" unless name.match?(/\A[A-Za-z0-9._-]+\z/)

        name
      end

      # @param segment [String]
      # @return [String]
      def camelize_segment(segment)
        SEGMENT_CAMEL.fetch(segment) { segment.split('_').map(&:capitalize).join }
      end

      # @param value [Object]
      # @return [Object]
      def deep_stringify(value)
        case value
        in Hash then value.to_h { |key, child| [key.to_s, deep_stringify(child)] }
        in Array then value.map { deep_stringify(it) }
        else value
        end
      end
    end
  end
end
