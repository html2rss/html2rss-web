# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Typed feature flag registry and runtime access.
    module Flags
      # @!attribute [r] name
      #   @return [Symbol]
      # @!attribute [r] env_key
      #   @return [String]
      # @!attribute [r] type
      #   @return [Symbol]
      # @!attribute [r] default
      #   @return [Object, Proc]
      # @!attribute [r] validator
      #   @return [Proc, nil]
      Definition = Data.define(:name, :env_key, :type, :default, :validator)
      DEFINITIONS = {
        auto_source_enabled: Definition.new(
          name: :auto_source_enabled,
          env_key: 'AUTO_SOURCE_ENABLED',
          type: :boolean,
          default: -> { development_or_test? },
          validator: nil
        ),
        async_feed_refresh_enabled: Definition.new(
          name: :async_feed_refresh_enabled,
          env_key: 'ASYNC_FEED_REFRESH_ENABLED',
          type: :boolean,
          default: false,
          validator: nil
        ),
        async_feed_refresh_stale_factor: Definition.new(
          name: :async_feed_refresh_stale_factor,
          env_key: 'ASYNC_FEED_REFRESH_STALE_FACTOR',
          type: :integer,
          default: 3,
          validator: ->(value) { value >= 1 }
        )
      }.freeze
      MANAGED_ENV_PREFIXES = %w[AUTO_SOURCE_ ASYNC_FEED_REFRESH_].freeze

      class << self
        # @return [Boolean]
        def auto_source_enabled?
          fetch(:auto_source_enabled)
        end

        # @return [Boolean]
        def async_feed_refresh_enabled?
          fetch(:async_feed_refresh_enabled)
        end

        # @return [Integer]
        def async_feed_refresh_stale_factor
          fetch(:async_feed_refresh_stale_factor)
        end

        # Validates all known flags and managed env key prefixes.
        #
        # @return [void]
        def validate!
          validate_unknown_feature_keys!
          DEFINITIONS.each_key { |name| fetch(name) }
          nil
        end

        private

        # @param name [Symbol]
        # @return [Object]
        def fetch(name)
          definition = DEFINITIONS.fetch(name) { raise ArgumentError, "Unknown flag '#{name}'" }
          parse_definition(definition)
        end

        # @param definition [Definition]
        # @return [Object]
        def parse_definition(definition)
          raw = ENV.fetch(definition.env_key, nil)
          value = raw.nil? ? resolve_default(definition.default) : parse_value(definition, raw)
          validate_value!(definition, value)
          value
        end

        # @param default_value [Object, Proc]
        # @return [Object]
        def resolve_default(default_value)
          default_value.respond_to?(:call) ? default_value.call : default_value
        end

        # @param definition [Definition]
        # @param raw [String]
        # @return [Object]
        def parse_value(definition, raw)
          return parse_boolean(definition, raw) if definition.type == :boolean
          return parse_integer(definition, raw) if definition.type == :integer

          raise ArgumentError, "Unknown flag type '#{definition.type}' for '#{definition.name}'"
        end

        # @param definition [Definition]
        # @param raw [String]
        # @return [Boolean]
        def parse_boolean(definition, raw)
          normalized = raw.to_s.strip.downcase
          return true if normalized == 'true'
          return false if normalized == 'false'

          raise ArgumentError, "Malformed flag '#{definition.env_key}': expected true/false, got '#{raw}'"
        end

        # @param definition [Definition]
        # @param raw [String]
        # @return [Integer]
        def parse_integer(definition, raw)
          Integer(raw, 10)
        rescue ArgumentError
          raise ArgumentError, "Malformed flag '#{definition.env_key}': expected integer, got '#{raw}'"
        end

        # @param definition [Definition]
        # @param value [Object]
        # @return [void]
        def validate_value!(definition, value)
          return unless definition.validator
          return if definition.validator.call(value)

          raise ArgumentError, "Malformed flag '#{definition.env_key}': value '#{value}' failed constraints"
        end

        # @return [void]
        def validate_unknown_feature_keys!
          known = DEFINITIONS.values.map(&:env_key)
          unknown = ENV.keys.select do |key|
            MANAGED_ENV_PREFIXES.any? { |prefix| key.start_with?(prefix) } && !known.include?(key)
          end
          return if unknown.empty?

          raise ArgumentError, "Unknown feature flags: #{unknown.sort.join(', ')}"
        end

        # @return [Boolean]
        def development_or_test?
          env = ENV.fetch('RACK_ENV', 'development')
          %w[development test].include?(env)
        end
      end
    end
  end
end
