# frozen_string_literal: true

require 'dry-validation'

module Html2rss
  class Selectors
    ##
    # Validates the configuration hash for :selectors.
    class Config < Dry::Validation::Contract
      # Required wrapper key used to validate dynamic selector names.
      NESTING_KEY = :dynamic_keys_workaround

      ##
      # Validates the configuration of the :items selector
      class Items < Dry::Validation::Contract
        params do
          required(:selector).filled(:string)
          optional(:order).filled(included_in?: %w[reverse])
          optional(:enhance).filled(:bool?)
          optional(:pagination).hash do
            required(:max_pages).filled(:integer, gt?: 0)
          end
        end
      end

      ##
      # Validates the configuration of a single selector.
      class Selector < Dry::Validation::Contract
        params do
          optional(:selector)
          optional(:extractor).filled(:string)
          optional(:attribute).filled(:string)
          optional(:static).filled(:string)
          optional(:post_process).array(:hash)
        end

        rule(:selector) do
          key(:selector).failure('`selector` must be a string') if value && !value.is_a?(String)
        end

        rule(:extractor) do
          # dependent on the extractor, validate required fields, (i.e. static, attribute)
          case value
          when 'attribute'
            key(:attribute).failure('`attribute` must be a string') unless values[:attribute].is_a?(String)
          when 'static'
            key(:static).failure('`static` must be a string') unless values[:static].is_a?(String)
          end
        end

        rule(:post_process).each do
          case (name = value[:name])
          when 'gsub'
            key(:pattern).failure('`pattern` must be a string') unless value[:pattern].is_a?(String)
            key(:replacement).failure('`replacement` must be a string') unless value[:replacement].is_a?(String)
          when 'substring'
            key(:start).failure('`start` must be an integer') unless value[:start].is_a?(Integer)
            key(:end).failure('`end` must be an integer or omitted') if !value[:end].nil? && !value[:end].is_a?(Integer)
          when 'template'
            key(:string).failure('`string` must be a string') unless value[:string].is_a?(String)
          when 'html_to_markdown', 'markdown_to_html', 'parse_time', 'parse_uri', 'sanitize_html'
            # nothing to validate
          when nil
            key(:post_process).failure('Missing post_processor `name`')
          else
            key(:post_process).failure("Unknown post_processor `name`: #{name}")
          end
        end
      end

      ##
      # Validates the configuration of the :enclosure Selector
      class Enclosure < Selector
        params do
          optional(:content_type).filled(:string, format?: %r{^[\w-]+/[\w-]+$})
        end
      end

      params do
        required(NESTING_KEY).hash
      end

      rule(NESTING_KEY) do
        value.each_pair do |selector_key, selector|
          case selector_key.to_sym
          when Selectors::ITEMS_SELECTOR_KEY
            Items.new.call(selector).errors.each { |error| key(selector_key).failure(error) }
          when :enclosure
            Enclosure.new.call(selector).errors.each { |error| key(selector_key).failure(error) }
          when :guid, :categories
            unless selector.is_a?(Array)
              key(selector_key).failure("`#{selector_key}` must be an array")
              next
            end

            key(selector_key).failure("`#{selector_key}` must contain at least one element") if selector.empty?

            selector.each do |name|
              next if values[NESTING_KEY].key?(name.to_sym)

              key(selector_key).failure("`#{selector_key}` references unspecified `#{name}`")
            end
          else
            # From here on, the selector is found under its "dynamic" selector_key
            Selector.new.call(selector).errors.each { |error| key(selector_key).failure(error) }
          end
        end
      end

      ##
      # Shortcut to validate the config.
      # @param config [Hash] the configuration hash to validate
      # @return [Dry::Validation::Result] the result of the validation
      def self.call(config)
        # dry-validation/schema does not support "Dynamic Keys" yet: https://github.com/dry-rb/dry-schema/issues/37
        # But :selectors contains mostly "dynamic" keys, as the user defines them to extract article attributes.
        # --> Validate the dynamic keys manually.
        # To be able to specify a `rule`, nest the config under NESTING_KEY and mark that as `required`.
        new.call(NESTING_KEY => config)
      end
    end
  end
end
