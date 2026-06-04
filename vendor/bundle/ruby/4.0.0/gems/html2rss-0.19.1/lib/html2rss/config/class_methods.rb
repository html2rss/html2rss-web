# frozen_string_literal: true

module Html2rss
  class Config
    ##
    # Public class-level helpers for loading, validating, and exporting config.
    module ClassMethods
      # Sentinel to differentiate omitted params from explicit `nil`.
      UNSET = Object.new.freeze

      ##
      # Returns the exported JSON Schema for html2rss configuration.
      #
      # @return [Hash{String => Object}] JSON Schema represented as a Ruby hash
      def json_schema
        Schema.json_schema
      end

      ##
      # Returns the exported JSON Schema as JSON.
      #
      # @param pretty [Boolean] whether to pretty-print the JSON output
      # @return [String] serialized JSON Schema
      def json_schema_json(pretty: true)
        pretty ? JSON.pretty_generate(json_schema) : JSON.generate(json_schema)
      end

      ##
      # Validates a configuration hash with the runtime validator.
      #
      # @param config [Hash{Symbol => Object}] the configuration hash
      # @param params [Hash{Symbol => Object}, Hash{String => Object}, nil] dynamic parameters for string formatting
      # @return [Dry::Validation::Result] validation result after defaults and deprecations are applied
      def validate(config, params: UNSET)
        prepared_config = prepare_for_validation(resolve_effective_config(config, params:))

        Validator.new.call(prepared_config)
      rescue DynamicParams::ParamsMissing => error
        prepared_config = prepare_for_validation(HashUtil.deep_symbolize_keys(config, context: 'config'))
        prepared_config[:dynamic_params_error] = error.message

        Validator.new.call(prepared_config)
      end

      ##
      # Returns the packaged JSON Schema file path.
      #
      # @return [String] absolute path to the packaged JSON Schema file
      def schema_path
        Schema.path
      end

      ##
      # Loads and validates a YAML configuration file.
      #
      # @param file [String] the YAML file to load
      # @param feed_name [String, nil] optional feed name for multi-feed files
      # @param multiple_feeds_key [Symbol] key under which multiple feeds are defined
      # @param params [Hash{Symbol => Object}, Hash{String => Object}, nil] dynamic parameters for string formatting
      # @return [Dry::Validation::Result] validation result after defaults and deprecations are applied
      def validate_yaml(file, feed_name = nil, multiple_feeds_key: MultipleFeedsConfig::CONFIG_KEY_FEEDS, params: UNSET)
        validate(load_yaml(file, feed_name, multiple_feeds_key:), params:)
      end

      ##
      # Loads the feed configuration from a YAML file.
      #
      # Supports multiple feeds defined under the specified key (default :feeds).
      #
      # @param file [String] the YAML file to load.
      # @param feed_name [String, nil] the feed name when using multiple feeds.
      # @param multiple_feeds_key [Symbol] the key under which multiple feeds are defined.
      # @return [Hash{Symbol => Object}] the configuration hash.
      # @raise [ArgumentError] if the file doesn't exist or feed is not found.
      # rubocop:disable Metrics/MethodLength
      def load_yaml(file, feed_name = nil, multiple_feeds_key: MultipleFeedsConfig::CONFIG_KEY_FEEDS)
        raise ArgumentError, "File '#{file}' does not exist" unless File.exist?(file)
        raise ArgumentError, "`#{multiple_feeds_key}` is a reserved feed name" if feed_name == multiple_feeds_key

        yaml = YAML.safe_load_file(file, symbolize_names: true)

        return yaml unless yaml.key?(multiple_feeds_key)

        unless feed_name
          available_feeds = yaml.fetch(multiple_feeds_key).keys.join(', ')
          raise ArgumentError,
                "Feed name is required under `#{multiple_feeds_key}`. Available feeds: #{available_feeds}"
        end

        config = yaml.dig(multiple_feeds_key, feed_name.to_sym)
        raise ArgumentError, "Feed '#{feed_name}' not found under `#{multiple_feeds_key}` key." unless config

        MultipleFeedsConfig.to_single_feed(config, yaml, multiple_feeds_key:)
      end
      # rubocop:enable Metrics/MethodLength

      ##
      # Processes the provided configuration hash, applying dynamic parameters if given,
      # and returns a new configuration object.
      #
      # @param config [Hash{Symbol => Object}] the configuration hash.
      # @param params [Hash{Symbol => Object}, Hash{String => Object}, nil] dynamic parameters for string formatting.
      # @return [Html2rss::Config] the configuration object.
      def from_hash(config, params: UNSET)
        new(resolve_effective_config(config, params:))
      end

      ##
      # Builds a top-level auto-source feed config for the public shortcut APIs.
      #
      # @param url [String] source page URL
      # @param items_selector [String, nil] optional selector hint for item extraction
      # @param request_controls [Html2rss::RequestControls, nil] explicit request controls to write
      # @return [Hash{Symbol => Object}] feed config hash ready for {from_hash}
      def auto_source_config(url:, items_selector: nil, request_controls: nil)
        config = {
          channel: default_config[:channel].merge(url:),
          auto_source: AutoSource::DEFAULT_CONFIG
        }

        request_controls ||= Html2rss::RequestControls.new
        request_controls.apply_to(config)

        config[:selectors] = { items: { selector: items_selector, enhance: true } } if items_selector
        config
      end

      ##
      # Provides a default configuration.
      #
      # @return [Hash{Symbol => Object}] a hash with default configuration values.
      def default_config
        {
          strategy: default_strategy_name,
          request: {
            max_redirects: RequestService::Policy::DEFAULTS[:max_redirects],
            max_requests: RequestService::Policy::DEFAULTS[:max_requests]
          },
          channel: { time_zone: 'UTC' },
          headers: RequestHeaders.browser_defaults,
          stylesheets: []
        }
      end

      # @return [Symbol] the default strategy for feed orchestration
      def default_strategy_name
        :auto
      end

      private

      def resolve_effective_config(config, params:)
        effective_config = HashUtil.deep_symbolize_keys(config, context: 'config')
        resolved_params = parameter_defaults(effective_config)
        unless params.equal?(UNSET) || params.nil?
          resolved_params.merge!(HashUtil.deep_symbolize_keys(params, context: 'params'))
        end

        effective_config[:headers] = DynamicParams.call(effective_config[:headers], resolved_params)
        effective_config[:channel] = DynamicParams.call(effective_config[:channel], resolved_params)

        effective_config
      end

      def parameter_defaults(config)
        config.fetch(:parameters, {})
              .filter_map do |name, definition|
                [name, definition[:default]] if definition.is_a?(Hash) && definition.key?(:default)
              end
              .to_h
      end

      def prepare_for_validation(config)
        Config::Preparer.new.call(HashUtil.deep_dup(config))
      end
    end
  end
end
