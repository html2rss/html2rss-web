# frozen_string_literal: true

require 'yaml'
begin
  require 'html2rss/configs'
rescue LoadError => error
  warn "[html2rss-web] Failed to load 'html2rss/configs': #{error.message}"
  raise
end

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
      ##
      # raised when the local config shape is invalid
      class InvalidConfig < RuntimeError; end
      FEED_EXTENSION_PATTERN = /\.(json|rss|xml)\z/
      EMBEDDED_FEED_NAME_PATTERN = %r{\A[^/]+/.+\z}

      # Path to local feed configuration file.
      CONFIG_FILE = 'config/feeds.yml'

      class << self
        ##
        # @param name [String, Symbol, #to_sym]
        # @return [Hash<Symbol, Any>]
        def find(name)
          normalized_name = normalize_name(name)
          config_hash = local_feed_config(normalized_name) || embedded_feed_config(normalized_name)
          raise NotFound, "Did not find local feed config at '#{normalized_name}'" unless config_hash

          apply_global_defaults(config_hash)
        end

        ##
        # @return [Hash<Symbol, Any>]
        def feeds
          snapshot.feeds.transform_values { |feed| deep_dup(feed.raw) }
        end

        ##
        # @return [Hash<Symbol, Any>]
        def global
          deep_dup(snapshot.global)
        end

        ##
        # @return [Hash<Symbol, Any>]
        def yaml
          YAML.safe_load_file(CONFIG_FILE, symbolize_names: true).freeze
        rescue Errno::ENOENT => error
          raise NotFound, "Configuration file not found: #{error.message}"
        end

        ##
        # @return [Html2rss::Web::ConfigSnapshot::Snapshot]
        def snapshot
          return @snapshot if @snapshot # rubocop:disable ThreadSafety/ClassInstanceVariable

          @snapshot = ConfigSnapshot.load(yaml) # rubocop:disable ThreadSafety/ClassInstanceVariable
        rescue KeyError, TypeError, ArgumentError => error
          raise InvalidConfig, "Invalid local config: #{error.message}"
        end

        ##
        # @param reason [String]
        # @return [nil]
        def reload!(reason: 'manual')
          @snapshot = nil # rubocop:disable ThreadSafety/ClassInstanceVariable
          SecurityLogger.log_cache_lifecycle('local_config', 'reload', reason: reason)
          nil
        end

        private

        # @param normalized_name [String]
        # @return [Hash{Symbol=>Object}, nil]
        def local_feed_config(normalized_name)
          config = snapshot.feeds[normalized_name.to_sym]
          return nil unless config

          deep_dup(config.raw)
        end

        # @param normalized_name [String]
        # @return [Hash{Symbol=>Object}, nil]
        def embedded_feed_config(normalized_name)
          return nil unless defined?(Html2rss::Configs)
          return nil unless normalized_name.match?(EMBEDDED_FEED_NAME_PATTERN)

          deep_dup(Html2rss::Configs.find_by_name(normalized_name))
        rescue Html2rss::Configs::ConfigNotFound
          nil
        end

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
        # @return [String] path without feed extension for feed lookup.
        def normalize_name(name)
          name.to_s.delete_prefix('/').sub(FEED_EXTENSION_PATTERN, '')
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
