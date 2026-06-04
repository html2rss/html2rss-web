# frozen_string_literal: true

module Html2rss
  class Config
    # Handles multiple feeds within a single configuration hash.
    # Individual feed configurations should be placed under the :feeds key,
    # where each feed name is the key for its feed configuration.
    # All global configuration keys (outside :feeds) are merged into each feed's settings.
    class MultipleFeedsConfig
      # Reserved YAML key under which multiple named feed configs are defined.
      CONFIG_KEY_FEEDS = :feeds

      class << self
        # Merges global configuration into each feed's configuration.
        #
        # @param config [Hash] The feed-specific configuration.
        # @param yaml [Hash] The full YAML configuration.
        # @param multiple_feeds_key [Symbol] The key under which multiple feeds are defined.
        # @return [Hash] The merged configuration.
        def to_single_feed(config, yaml, multiple_feeds_key: CONFIG_KEY_FEEDS)
          global_keys = yaml.keys - [multiple_feeds_key]
          global_keys.each do |key|
            config[key] = merge_key(config, yaml, key)
          end
          config
        end

        private

        # Merges a specific global key from the YAML configuration into the feed configuration.
        #
        # @param config [Hash] The feed-specific configuration.
        # @param yaml [Hash] The full YAML configuration.
        # @param key [Symbol] The global configuration key to merge.
        # @return [Object] The merged value for the key.
        def merge_key(config, yaml, key)
          global_value = yaml.fetch(key, nil)
          local_value = config[key]
          case local_value
          when Hash
            global_value.is_a?(Hash) ? HashUtil.deep_merge(global_value, local_value) : local_value
          when Array
            global_value.is_a?(Array) ? global_value + local_value : local_value
          else
            local_value.nil? ? global_value : local_value
          end
        end
      end
    end
  end
end
