# frozen_string_literal: true

require 'erb'
require 'yaml'
require_relative 'runtime_env'

module Html2rss
  module Web
    ##
    # Loads and normalizes feed configuration from disk.
    #
    # Keeping lookup/defaulting here gives the rest of the app one predictable
    # config shape instead of repeating file parsing and fallback logic.
    module LocalConfig
      @mutex = Mutex.new
      @snapshot = nil

      ##
      # raised when the local config wasn't found
      class NotFound < RuntimeError; end
      ##
      # raised when the local config shape is invalid
      class InvalidConfig < RuntimeError; end
      FEED_EXTENSION_PATTERN = /\.(json|rss|xml)\z/

      # Path to local feed configuration file.
      CONFIG_FILE = 'config/feeds.yml'

      class << self
        ##
        # @param name [String, Symbol, #to_sym]
        # @return [Hash<Symbol, Any>]
        def find(name)
          normalized_name = normalize_name(name)
          config_hash = local_feed_config(normalized_name) || registry_feed_config(normalized_name)
          raise NotFound, "Did not find local feed config at '#{normalized_name}'" unless config_hash

          config_hash
        end

        ##
        # @return [Hash<Symbol, Any>]
        def feeds
          snapshot.feeds.transform_values { StructuredData.deep_dup(it.raw) }
        end

        ##
        # @return [Hash<Symbol, Any>]
        def global
          StructuredData.deep_dup(snapshot.global)
        end

        ##
        # @return [Html2rss::Web::ConfigSnapshot::Snapshot]
        def snapshot
          @mutex.synchronize { @snapshot ||= load_snapshot }
        rescue KeyError, TypeError, ArgumentError => error
          raise InvalidConfig, "Invalid local config: #{error.message}"
        end

        ##
        # Reparses the current config file without touching memoized runtime
        # state. Health checks use this path so config drift shows up without
        # forcing live request handlers onto a reload path.
        #
        # @return [Hash<Symbol, Any>]
        def load_yaml
          template = File.read(CONFIG_FILE)
          YAML.safe_load(ERB.new(template, trim_mode: '-').result, symbolize_names: true).freeze
        rescue Errno::ENOENT => error
          raise NotFound, "Configuration file not found: #{error.message}"
        end

        ##
        # Reparses and normalizes the current config file without mutating the
        # memoized runtime snapshot.
        #
        # @return [Html2rss::Web::ConfigSnapshot::Snapshot]
        def load_snapshot
          ConfigSnapshot.load(load_yaml)
        rescue KeyError, TypeError, ArgumentError => error
          raise InvalidConfig, "Invalid local config: #{error.message}"
        end

        ##
        # @param reason [String]
        # @return [nil]
        def reload!(reason: 'manual')
          @mutex.synchronize { @snapshot = nil }
          Registry::Index.reload!
          Observability.emit(
            event_name: 'cache.lifecycle',
            outcome: 'success',
            details: { component: 'local_config', event: 'reload', reason: }
          )
          nil
        end

        private

        # @param normalized_name [String]
        # @return [Hash{Symbol=>Object}, nil]
        def local_feed_config(normalized_name)
          config = snapshot.feeds[normalized_name.to_sym]
          return nil unless config

          StructuredData.deep_dup(config.raw)
        end

        # @param normalized_name [String]
        # @return [Hash{Symbol=>Object}, nil]
        def registry_feed_config(normalized_name)
          Registry::Index.current.config_for(normalized_name)
        end

        # @param name [String, Symbol, #to_s]
        # @return [String] path without feed extension for feed lookup.
        def normalize_name(name)
          name.to_s.delete_prefix('/').sub(FEED_EXTENSION_PATTERN, '')
        end
      end
    end
  end
end
