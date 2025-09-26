# frozen_string_literal: true

require 'yaml'

module Html2rss
  module Web
    ##
    # Provides helper methods to deal with the local config file at `CONFIG_FILE`.
    module LocalConfig
      ##
      # raised when the local config wasn't found
      class NotFound < RuntimeError; end

      CONFIG_FILE = 'config/feeds.yml'

      class << self
        ##
        # @param name [String, Symbol, #to_sym]
        # @return [Hash<Symbol, Any>]
        def find(name)
          config = feeds.fetch(name.to_sym) { raise NotFound, "Did not find local feed config at '#{name}'" }
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
        # @return [Array<Symbol>] names of locally available feeds
        def feed_names
          feeds.keys
        end

        ##
        # @return [Hash<Symbol, Any>]
        def yaml
          YAML.safe_load_file(CONFIG_FILE, symbolize_names: true).freeze
        rescue Errno::ENOENT => error
          raise NotFound, "Configuration file not found: #{error.message}"
        end

        private

        def apply_global_defaults(config)
          global_config = global

          config[:stylesheets] ||= deep_dup(global_config[:stylesheets]) if global_config[:stylesheets]
          config[:headers] ||= deep_dup(global_config[:headers]) if global_config[:headers]

          config
        end

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
