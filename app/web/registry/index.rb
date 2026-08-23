# frozen_string_literal: true

require 'uri'
require_relative '../config/structured_data'

module Html2rss
  module Web
    module Registry
      ##
      # Unified status model for registry state across API, CLI, and index.
      Status = Data.define(
        :id,
        :mode,
        :version,
        :staged_version,
        :updated_at,
        :sync_url,
        :last_error
      ) do
        ##
        # @param id [String, Symbol]
        # @param mode [Symbol]
        # @param version [String, nil]
        # @param staged_version [String, nil]
        # @param updated_at [Time, nil]
        # @param sync_url [String, nil]
        # @param last_error [String, nil]
        def initialize(id:, mode:, version: nil, staged_version: nil, updated_at: nil, sync_url: nil, last_error: nil)
          super
        end
      end

      ##
      # Sole feed repository combining registry bundles and local feeds.
      class Index # rubocop:disable Metrics/ClassLength
        ##
        # Immutable container holding a loaded registry bundle's manifest, configs, and catalog entries.
        RegistryBundle = Data.define(:registry_id, :manifest, :configs, :catalog_entries)

        @mutex = Mutex.new
        @current = nil

        class << self
          ##
          # @return [Index]
          def current
            @mutex.synchronize { @current ||= new }
          end

          ##
          # @return [nil]
          def reload!
            @mutex.synchronize { @current = nil }
            Config.reload!
            nil
          end
        end

        ##
        # @param feed_id [String, Symbol]
        # @return [Hash{Symbol => Object}, nil]
        def config_for(feed_id)
          id = normalize_feed_id(feed_id)
          local = local_config_for(id)
          return local if local

          loaded_bundles.each_value do |bundle|
            config = bundle.configs[id]
            return StructuredData.deep_dup(config) if config
          end

          nil
        end

        ##
        # @return [Array<Html2rss::Registry::CatalogEntry>]
        def catalog_entries
          registry_entries = build_registry_catalog_entries
          local_entries = build_local_catalog_entries
          registry_entries.merge(local_entries).values.sort_by(&:id)
        end

        ##
        # @return [Array<Hash{Symbol => Object}>]
        def catalog_rows
          catalog_entries.map(&:to_h)
        end

        ##
        # @param registry_id [String, Symbol]
        # @return [RegistryBundle, nil]
        def bundle_for(registry_id)
          loaded_bundles[registry_id.to_s]
        end

        ##
        # @return [Array<Status>]
        def status # rubocop:disable Metrics/MethodLength
          Config.precedence.map do |registry_id|
            definition = Config.entry(registry_id)
            bundle = loaded_bundles[registry_id]
            sync_state = Store.sync_state(registry_id)
            mode = definition.mode
            sync_url = mode == :sync ? ChannelResolver.resolve(definition) : nil

            Status.new(
              id: registry_id,
              mode:,
              version: bundle&.manifest&.version,
              staged_version: Store.staged_version(registry_id),
              updated_at: Store.manifest_mtime(bundle_directory(definition)),
              sync_url:,
              last_error: sync_state.last_error
            )
          end
        end

        ##
        # @param registry_id [String, Symbol]
        # @return [Status, nil]
        def status_entry_for(registry_id)
          status.find { it.id == registry_id.to_s }
        end

        private

        def loaded_bundles
          @loaded_bundles ||= Config.precedence.to_h { [it, load_bundle(it)] }.compact
        end

        def build_registry_catalog_entries # rubocop:disable Metrics/MethodLength
          Config.precedence.each_with_object({}) do |registry_id, rows|
            next unless Config.catalog_enabled?(registry_id)

            bundle = loaded_bundles[registry_id]
            next unless bundle

            bundle.catalog_entries.each do |entry|
              entry_id = entry.id
              rows[entry_id] ||= Html2rss::Registry::CatalogEntry.new(
                id: entry_id,
                path: entry.path,
                directory: entry.directory,
                channel: entry.channel,
                parameters: entry.parameters,
                source: 'registry',
                registry: registry_id
              )
            end
          end
        end

        def build_local_catalog_entries
          LocalConfig.feeds.filter_map do |feed_name, feed_config|
            entry = build_local_catalog_entry(feed_name, feed_config)
            [entry.id, entry] if entry
          end.to_h
        end

        def load_bundle(registry_id) # rubocop:disable Metrics/MethodLength
          definition = Config.entry(registry_id)
          directory = bundle_directory(definition)
          return nil unless directory && File.directory?(directory) && Store.bundle_present_at?(directory)

          trust_opts = if definition.mode == :path
                         { trust: :integrity_only }
                       else
                         { trust: :signed, public_keys: definition.public_keys }
                       end
          bundle_data = Html2rss::Registry::Bundle.load(directory, **trust_opts)
          bundle = RegistryBundle.new(
            registry_id:,
            manifest: bundle_data.manifest,
            configs: bundle_data.configs,
            catalog_entries: bundle_data.catalog_entries
          )
          enforce_scrape_policy!(definition, bundle)
          bundle
        rescue Html2rss::Registry::Error => error
          raise Errors::LoadError, "Failed to load registry '#{registry_id}': #{error.message}"
        end

        def enforce_scrape_policy!(definition, bundle)
          allowed = definition.allowed_channel_domains
          return if allowed.empty?

          bundle.configs.each do |feed_id, config|
            next if host_allowed?(config.dig(:channel, :url), allowed)

            raise Errors::LoadError, "Registry '#{definition.id}' config '#{feed_id}' host not allowed"
          end
        end

        def host_allowed?(url, allowed)
          host = URI.parse(url.to_s).host&.downcase rescue nil # rubocop:disable Style/RescueModifier
          return false unless host

          allowed.any? { |domain| domain_matches?(host, domain.downcase) }
        end

        def domain_matches?(host, domain)
          host == domain || host.end_with?(".#{domain}")
        end

        def bundle_directory(definition)
          definition.mode == :path ? definition.path : Store.registry_dir(definition.id)
        end

        def normalize_feed_id(feed_id)
          feed_id.to_s.delete_prefix('/').sub(LocalConfig::FEED_EXTENSION_PATTERN, '')
        end

        def local_config_for(feed_id)
          feeds = LocalConfig.feeds
          feed = feeds[feed_id.to_sym] || feeds[feed_id]
          feed ? StructuredData.deep_dup(feed) : nil
        rescue StandardError
          nil
        end

        def build_local_catalog_entry(feed_name, feed_config) # rubocop:disable Metrics/MethodLength
          directory = feed_config[:directory] || {}
          title = directory[:title]&.to_s
          return nil if title.to_s.strip.empty?

          id = feed_name.to_s
          channel = feed_config[:channel] || {}
          Html2rss::Registry::CatalogEntry.new(
            id:,
            path: "/#{id}.rss",
            source: 'local',
            directory: Html2rss::Registry::CatalogBuilder.directory_payload(directory, title),
            channel: Html2rss::Registry::CatalogBuilder.channel_payload(channel, title),
            parameters: { schema: {}, defaults: {} },
            registry: nil
          )
        end
      end
    end
  end
end
