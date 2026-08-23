# frozen_string_literal: true

require 'erb'
require 'yaml'
require_relative 'runtime_env'
require_relative 'structured_data'

module Html2rss
  module Web
    ##
    # Loads and normalizes local feed configuration from disk.
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
        # @param feed_id [String, Symbol]
        # @return [Hash{Symbol => Object}]
        def find(feed_id)
          normalized = feed_id.to_s.delete_prefix('/').sub(FEED_EXTENSION_PATTERN, '')
          config = snapshot.feeds[normalized.to_sym]
          raise NotFound, "Did not find local feed config at '#{normalized}'" unless config

          Config::StructuredData.deep_dup(config.raw)
        end

        ##
        # @return [Hash{Symbol => Hash{Symbol => Object}}]
        def feeds
          snapshot.feeds.transform_values { Config::StructuredData.deep_dup(it.raw) }
        end

        ##
        # @return [Hash{Symbol => Object}]
        def global
          Config::StructuredData.deep_dup(snapshot.global)
        end

        ##
        # @return [Html2rss::Web::ConfigSnapshot::Snapshot]
        def snapshot
          @mutex.synchronize { @snapshot ||= load_snapshot }
        rescue KeyError, TypeError, ArgumentError => error
          raise InvalidConfig, "Invalid local config: #{error.message}"
        end

        ##
        # @return [Hash{Symbol => Object}]
        def load_yaml
          template = File.read(CONFIG_FILE)
          YAML.safe_load(ERB.new(template, trim_mode: '-').result, symbolize_names: true).freeze
        rescue Errno::ENOENT => error
          raise NotFound, "Configuration file not found: #{error.message}"
        end

        ##
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
      end
    end
  end
end
