# frozen_string_literal: true

require 'yaml'

module Html2rss
  module Web
    ##
    # Loads and normalizes feed configuration from disk.
    #
    # Keeping lookup/defaulting here gives the rest of the app one predictable
    # config shape instead of repeating file parsing and fallback logic.
    module LocalConfig
      ##
      # raised when the local config wasn't found
      class NotFound < RuntimeError; end

      # Path to local feed configuration file.
      CONFIG_FILE = 'config/feeds.yml'

      class << self
        ##
        # @param name [String, Symbol, #to_sym]
        # @return [Hash<Symbol, Any>]
        def find(name)
          normalized_name = normalize_name(name)
          config = feeds.fetch(normalized_name.to_sym) do
            raise NotFound, "Did not find local feed config at '#{normalized_name}'"
          end
          config = deep_dup(config)

          apply_global_defaults(config)
        end

        ##
        # @return [Hash<Symbol, Any>]
        def feeds
          yaml.fetch(:feeds, {})
        end

        ##
        # @return [Hash<Symbol, Any>]
        def global
          yaml.reject { |key| key == :feeds }
        end

        ##
        # @return [Hash<Symbol, Any>]
        def yaml
          YAML.safe_load_file(CONFIG_FILE, symbolize_names: true).freeze
        rescue Errno::ENOENT => error
          raise NotFound, "Configuration file not found: #{error.message}"
        end

        private

        # Applies global defaults only when feed-level keys are absent.
        #
        # @param config [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def apply_global_defaults(config)
          global_config = global

          config[:stylesheets] ||= deep_dup(global_config[:stylesheets]) if global_config[:stylesheets]
          config[:headers] ||= deep_dup(global_config[:headers]) if global_config[:headers]

          config
        end

        # @param name [String, Symbol, #to_s]
        # @return [String] basename without extension for feed lookup.
        def normalize_name(name)
          File.basename(name.to_s, '.*')
        end

        # Deep-duplicates nested config structures to avoid mutating shared data.
        #
        # @param value [Object]
        # @return [Object]
        def deep_dup(value)
          case value
          when Hash
            value.transform_values { |val| deep_dup(val) }
          when Array
            value.map { |element| deep_dup(element) }
          else
            value
          end
        end
      end
    end
  end
end
