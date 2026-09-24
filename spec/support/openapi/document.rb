# frozen_string_literal: true

##
# Typed OpenAPI document helpers for the rspec-openapi post-process hook.
module Openapi
  ##
  # Collapses recorded request paths to server-relative OpenAPI templates.
  module PathTemplate
    module_function

    # @param path [String, Symbol]
    # @param studio_posts [Hash, #keys] studio path segment → handler map
    # @return [String]
    # rubocop:disable-next Metrics/MethodLength -- path collapse branches stay local
    def normalize(path, studio_posts:)
      studio = Regexp.union(Array(studio_posts.keys).map(&:to_s)).source
      token_path = %r{\A/api/v1/feeds/(?!(?:#{studio})\z)[^/]+\z}
      original = path.to_s
      normalized = if original.match?(token_path)
                     '/feeds/{token}'
                   elsif original.start_with?('/api/v1')
                     original.delete_prefix('/api/v1')
                   else
                     original
                   end
      normalized.empty? ? '/' : normalized
    end
  end

  ##
  # Mutates the symbol-keyed OpenAPI document: path merge, web stamps, hull refs.
  module Document # rubocop:disable Metrics/ModuleLength -- one deep generation seam
    class ConflictError < StandardError
    end

    SELECTORS_DOCUMENT_REF = { '$ref': '#/components/schemas/SelectorsDocument' }.freeze
    PREVIEW_SAMPLE_ITEM_REF = { '$ref': '#/components/schemas/PreviewSampleItem' }.freeze
    SELECTOR_CANDIDATES_REF = { '$ref': '#/components/schemas/SelectorCandidates' }.freeze
    ITEMS_CANDIDATE_REF = { '$ref': '#/components/schemas/ItemsSelectorCandidate' }.freeze
    FIELD_CANDIDATE_REF = { '$ref': '#/components/schemas/FieldSelectorCandidate' }.freeze
    OPEN_VALUE_DESCRIPTION = 'JSON-ish value, or null when the issue carries none.'

    # rubocop:disable-next Metrics/ClassLength -- generation hook owns path merge + stamps
    class << self
      # @param spec [Hash] symbol-keyed OpenAPI document
      # @param components [Hash] schema name → schema; defaults to {Openapi::JsonSchema.components}
      # @return [void]
      # rubocop:disable-next Metrics/MethodLength -- ordered mutate steps for one document
      def apply!(spec, components: JsonSchema.components)
        path_map = spec[:paths]
        if path_map.is_a?(Hash)
          studio_posts = Html2rss::Web::Routes::ApiV1::FeedRoutes::STUDIO_POSTS
          spec[:paths] = normalize_paths(path_map, studio_posts:)
        end

        walk(spec) { |node| stamp_issue_schema(node) }
        schemas = ((spec[:components] ||= {})[:schemas] ||= {})
        publish_web_schemas(schemas)
        merge_components(schemas, components)
        rewrite_hulls(spec, selectors: schemas.key?(:SelectorsDocument))
        spec.replace(deep_sort(spec))
      end

      private

      def deep_sort(value)
        case value
        in Hash then value.keys.sort_by(&:to_s).to_h { |key| [key, deep_sort(value[key])] }
        in Array then value.map { deep_sort(it) }
        else value
        end
      end

      def normalize_paths(path_map, studio_posts:)
        path_map.each_with_object({}) do |(raw, operations), paths|
          add_operations(paths, PathTemplate.normalize(raw, studio_posts:), operations)
        end
      end

      def add_operations(paths, normalized, operations)
        key = normalized.to_sym
        bucket = paths[key] ||= {}
        operations.each do |verb, doc|
          bucket[verb] = merge_operation(bucket[verb], doc)
          decorate_operation(bucket[verb], normalized)
        end
      end

      def merge_operation(existing, operation_doc)
        return deep_sort(operation_doc) unless existing

        raise_description_conflict!(existing, operation_doc)
        merged = existing.merge(operation_doc)
        merged[:responses] = merge_responses(existing[:responses] || {}, operation_doc[:responses] || {})
        merged[:parameters] = [*(existing[:parameters] || []), *(operation_doc[:parameters] || [])]
        merged[:parameters].uniq! { |parameter| [parameter[:name], parameter[:in]] }
        deep_sort(merged)
      end

      def decorate_operation(doc, normalized)
        doc[:description] ||= doc[:summary]
        ensure_token_parameter(doc) if normalized.include?('{token}')
      end

      def ensure_token_parameter(doc)
        params = doc[:parameters] ||= []
        return if params.any? { it[:name] == 'token' && it[:in] == 'path' }

        params << { name: 'token', in: 'path', required: true, schema: { type: 'string' } }
      end

      def merge_responses(existing_responses, new_responses)
        (existing_responses.keys | new_responses.keys).each_with_object({}) do |status, merged|
          current = existing_responses[status] || {}
          incoming = new_responses[status] || {}
          merged[status] = current.merge(incoming).tap do |response|
            copy_merged_content(response, current, incoming)
            copy_merged_headers(response, current, incoming)
            response[:description] = merged_description(current, incoming)
          end
        end
      end

      def copy_merged_content(response, current, incoming)
        left = Hash(current[:content])
        right = Hash(incoming[:content])
        types = left.keys | right.keys
        return if types.empty?

        response[:content] = types.to_h { |type| [type, left.fetch(type, {}).merge(right.fetch(type, {}))] }
      end

      def copy_merged_headers(response, current, incoming)
        left = Hash(current[:headers])
        right = Hash(incoming[:headers])
        return if left.empty? && right.empty?

        response[:headers] = left.merge(right)
      end

      def raise_description_conflict!(left, right) = merged_description(left, right)

      def merged_description(*nodes)
        descriptions = nodes.filter_map { it[:description]&.to_s&.strip }.reject(&:empty?).uniq
        case descriptions
        in [] then nil
        in [one] then one
        else
          raise ConflictError, "conflicting OpenAPI descriptions: #{descriptions.join(' | ')}"
        end
      end

      def walk(node, &)
        case node
        in Hash
          yield node
          node.each_value { walk(it, &) }
        in Array
          node.each { walk(it, &) }
        else
          nil
        end
      end

      def stamp_issue_schema(node)
        properties = node[:properties]
        return unless properties.is_a?(Hash) && issue_schema?(properties)

        stamp_issue_code(properties[:code])
        stamp_open_value(properties[:expected])
        stamp_open_value(properties[:actual])
      end

      def issue_schema?(properties) = %i[actual code expected message path].all? { properties.key?(it) }

      def stamp_issue_code(code)
        return unless code.is_a?(Hash)

        code[:type] = 'string'
        code[:enum] = Html2rss::Config::CODES.map(&:to_s).sort
      end

      def stamp_open_value(value)
        return unless value.is_a?(Hash)

        value.replace(description: OPEN_VALUE_DESCRIPTION)
      end

      # rubocop:disable-next Metrics/MethodLength -- four web component schemas in one stamp
      def publish_web_schemas(schemas)
        names = bucket_names
        schemas[:PreviewSampleItem] = {
          description: 'One preview meadow row returned by POST /feeds/preview.',
          type: 'object', required: %w[title],
          properties: Html2rss::Web::Api::V1::PreviewSamples::SAMPLE_KEYS.to_h do |key|
            [key.to_sym, key == 'title' ? { type: 'string' } : { type: %w[string null] }]
          end
        }
        schemas[:SelectorCandidates] = {
          description: 'Ranked selector candidates. Empty buckets are a successful response.',
          type: 'object', required: names.map(&:to_s), additionalProperties: false,
          properties: names.to_h do |name|
            ref = name == :items ? ITEMS_CANDIDATE_REF : FIELD_CANDIDATE_REF
            [name, { type: 'array', items: ref.dup }]
          end
        }
        schemas[:ItemsSelectorCandidate] = {
          description: 'One ranked items selector with a sample headline. Best match is first.',
          type: 'object', required: %w[selector enhance sample], additionalProperties: false,
          properties: {
            selector: { type: 'string' },
            enhance: { type: 'boolean' },
            sample: { type: 'string', description: 'Visible text of a matched node' }
          }
        }
        schemas[:FieldSelectorCandidate] = {
          description: 'One ranked field selector with a sample headline. Best match is first.',
          type: 'object', required: %w[selector sample], additionalProperties: false,
          properties: {
            selector: { type: 'string' },
            sample: { type: 'string', description: 'Visible text of a matched node' }
          }
        }
      end

      def merge_components(schemas, components)
        return if components.nil? || components.empty?

        symbolize(components).each { |name, schema| schemas[name] = schema }
      end

      def symbolize(value)
        require 'rspec/openapi' unless defined?(RSpec::OpenAPI::KeyTransformer)

        RSpec::OpenAPI::KeyTransformer.symbolize(value)
      end

      def bucket_names = Html2rss::Web::Api::V1::SuggestSelectors::BUCKET_NAMES.map { it.to_s.to_sym }

      def rewrite_hulls(spec, selectors:)
        walk(spec) do |node|
          properties = node[:properties]
          next unless properties.is_a?(Hash)

          rewrite_selectors_property(properties) if selectors
          rewrite_sample_items_property(properties)
          rewrite_candidates_property(properties)
        end
      end

      def rewrite_selectors_property(properties)
        schema = properties[:selectors]
        return unless selectors_document_hull?(schema)

        properties[:selectors] = if nullable_schema?(schema)
                                   { oneOf: [{ type: 'null' }, SELECTORS_DOCUMENT_REF.dup] }
                                 else
                                   SELECTORS_DOCUMENT_REF.dup
                                 end
      end

      def nullable_schema?(schema)
        schema[:nullable] || (schema[:type].is_a?(Array) && schema[:type].include?('null'))
      end

      def selectors_document_hull?(schema)
        return false unless schema.is_a?(Hash) && !schema.key?(:$ref)

        items = schema.dig(:properties, :items)
        items.is_a?(Hash) && items.dig(:properties, :selector).is_a?(Hash)
      end

      def rewrite_sample_items_property(properties)
        schema = properties[:sample_items]
        return unless sample_items_hull?(schema)

        properties[:sample_items] = { type: 'array', items: PREVIEW_SAMPLE_ITEM_REF.dup }
      end

      def sample_items_hull?(schema)
        schema.is_a?(Hash) && schema[:type] == 'array' && !schema.key?(:$ref) &&
          schema.dig(:items, :properties, :title).is_a?(Hash)
      end

      def rewrite_candidates_property(properties)
        schema = properties[:candidates]
        return unless candidates_hull?(schema)

        properties[:candidates] = SELECTOR_CANDIDATES_REF.dup
      end

      def candidates_hull?(schema)
        return false unless schema.is_a?(Hash) && !schema.key?(:$ref)

        properties = schema[:properties]
        properties.is_a?(Hash) && bucket_names.all? { properties[it].is_a?(Hash) }
      end
    end
  end
end
