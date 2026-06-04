# frozen_string_literal: true

require 'json'
require 'yaml'

module Html2rss
  ##
  # The provided configuration is used to generate the RSS feed.
  # This class provides methods to load and process configuration from a YAML file,
  # supporting both single and multiple feed configurations.
  #
  # Configuration is validated during initialization.
  class Config
    # Raised when a configuration hash fails runtime validation.
    class InvalidConfig < Html2rss::Error; end
    extend ClassMethods

    ##
    # Initializes the configuration object.
    #
    # Processes deprecated attributes, applies default values, and validates the configuration.
    #
    # @param config [Hash{Symbol => Object}] the configuration hash.
    # @raise [InvalidConfig] if the configuration fails validation.
    def initialize(config)
      @request_controls = RequestControls.from_config(config)
      prepared_config = Preparer.new.call(config)
      validated_config = validated_config_for(prepared_config)

      @config = validated_config.freeze
      @request_controls = request_controls.with_effective_values(
        strategy: validated_config[:strategy],
        max_redirects: validated_config.dig(:request, :max_redirects),
        max_requests: validated_config.dig(:request, :max_requests)
      )
    end

    # @return [Symbol, nil] selected request strategy
    def strategy = request_controls.strategy
    # @return [Integer, nil] configured redirect budget
    def max_redirects = request_controls.max_redirects
    # @return [Integer, nil] configured request budget
    def max_requests = request_controls.max_requests
    # @return [Array<Hash>] stylesheet definitions
    def stylesheets = config[:stylesheets]

    ##
    # @return [Boolean] whether max_requests was explicitly configured by the caller
    def explicit_max_requests?
      request_controls.explicit?(:max_requests)
    end

    ##
    # @return [Html2rss::RequestControls] request controls with provenance
    attr_reader :request_controls

    # @return [Hash{String => String}] normalized HTTP headers
    def headers = config[:headers]
    # @return [Hash{Symbol => Object}] channel configuration
    def channel = config[:channel]
    # @return [String] source channel URL
    def url = config.dig(:channel, :url)
    # @return [String, nil] configured channel time zone
    def time_zone = config.dig(:channel, :time_zone)

    # @return [Hash{Symbol => Object}] request envelope configuration
    def request = config[:request]

    # @return [Hash{Symbol => Object}, nil] selectors configuration
    def selectors = config[:selectors]
    # @return [Hash{Symbol => Object}, nil] auto-source configuration
    def auto_source = config[:auto_source]

    private

    attr_reader :config

    # Normalizes raw config input before validation.
    class Preparer
      ##
      # @param config [Hash{Symbol => Object}] raw config input
      # @return [Hash{Symbol => Object}] config with defaults and deprecations applied
      def call(config)
        config = config.dup if config.frozen?

        config = handle_deprecated_channel_attributes(config)
        config = apply_default_config(config)
        config = apply_default_selectors_config(config) if config[:selectors]
        config = apply_default_auto_source_config(config) if config[:auto_source]

        config
      end

      private

      def handle_deprecated_channel_attributes(config)
        { strategy: Config.default_strategy_name, headers: {} }.each_pair do |key, default_value|
          if !config[key] && (value = config.dig(:channel, key))
            Log.warn("The `channel.#{key}` key is deprecated. Please move the definition of `#{key}` to the top level.")
            config[key] = value
          end

          config[key] ||= default_value
        end

        config
      end

      def apply_default_config(config)
        HashUtil.deep_merge(Config.default_config, config)
      end

      def apply_default_selectors_config(config)
        HashUtil.deep_merge({ selectors: Selectors::DEFAULT_CONFIG }, config)
      end

      def apply_default_auto_source_config(config)
        HashUtil.deep_merge({ auto_source: Html2rss::AutoSource::DEFAULT_CONFIG }, config)
      end
    end

    def validated_config_for(config)
      validator = Validator.new.call(config)

      raise InvalidConfig, "Invalid configuration: #{validator.errors.to_h}" unless validator.success?

      normalized_headers(validator.to_h)
    end

    def normalized_headers(validated_config)
      validated_config[:headers] = RequestHeaders.normalize(
        validated_config[:headers],
        channel_language: validated_config.dig(:channel, :language),
        url: validated_config.dig(:channel, :url)
      )
      validated_config
    end
  end
end
