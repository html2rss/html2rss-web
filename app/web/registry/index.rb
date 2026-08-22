# frozen_string_literal: true

require 'uri'

module Html2rss
  module Web
    module Registry
      ##
      # Sole merge owner for registry bundles and local {LocalConfig} feeds.
      class Index # rubocop:disable Metrics/ClassLength
        RegistryBundle = Data.define(:registry_id, :manifest, :configs, :catalog_entries)
        StatusEntry = Data.define(:id, :version, :updated_at, :sync_mode)

        CatalogRow = Data.define(
          :id,
          :path,
          :directory,
          :channel,
          :parameters,
          :source,
          :registry
        ) do
          ##
          # @param entry [Html2rss::Registry::CatalogEntry]
          # @param registry_id [String]
          # @return [CatalogRow]
          def self.from_entry(entry, registry_id)
            new(
              id: entry.id,
              path: entry.path,
              directory: entry.directory,
              channel: entry.channel,
              parameters: entry.parameters,
              source: 'registry',
              registry: registry_id
            )
          end

          ##
          # @param feed_name [String, Symbol]
          # @param feed_config [Hash{Symbol => Object}]
          # @return [CatalogRow, nil]
          def self.from_local_feed(feed_name, feed_config) # rubocop:disable Metrics/MethodLength
            directory = feed_config[:directory] || {}
            title = directory[:title]
            return nil if title.to_s.strip.empty?

            id = feed_name.to_s
            channel = feed_config[:channel] || {}
            new(
              id:,
              path: "/#{id}.rss",
              source: 'local',
              directory: Html2rss::Registry::CatalogBuilder.directory_payload(directory, title),
              channel: Html2rss::Registry::CatalogBuilder.channel_payload(channel, title),
              parameters: { schema: {}, defaults: {} },
              registry: nil
            )
          end

          ##
          # @return [Hash{Symbol => Object}]
          def to_h
            super.compact
          end
        end

        @mutex = Mutex.new
        @current = nil

        class << self
          ##
          # @return [Index]
          def current
            @mutex.synchronize { @current ||= new }
          end

          ##
          # Clears memoized bundles (tests and development reload).
          #
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
          normalized_id = normalize_feed_id(feed_id)
          local_config = local_config_for(normalized_id)
          return local_config if local_config

          loaded_bundles.each_value do |bundle|
            config = bundle.configs[normalized_id]
            return deep_dup(config) if config
          end

          nil
        end

        ##
        # @return [Array<Hash{Symbol => Object}>] catalog rows in HTTP wire shape
        def catalog_rows
          rows = registry_catalog_rows
          local_catalog_rows.each { |row| rows[row.id] = row }
          rows.values.sort_by(&:id).map(&:to_h)
        end

        ##
        # @param registry_id [String, Symbol]
        # @return [RegistryBundle, nil]
        def bundle_for(registry_id)
          loaded_bundles[registry_id.to_s]
        end

        ##
        # @return [Array<StatusEntry>]
        def status
          Config.precedence.map do |registry_id|
            entry = Config.entry(registry_id)
            bundle = loaded_bundles[registry_id]
            StatusEntry.new(
              id: registry_id,
              version: bundle&.manifest&.version,
              updated_at: bundle_updated_at(registry_id),
              sync_mode: entry.mode
            )
          end
        end

        private

        ##
        # @return [Hash{String => CatalogRow}]
        def registry_catalog_rows
          Config.precedence.each_with_object({}) do |registry_id, rows|
            next unless Config.catalog_enabled?(registry_id)

            bundle = loaded_bundles[registry_id]
            next unless bundle

            bundle.catalog_entries.each do |entry|
              rows[entry.id] ||= CatalogRow.from_entry(entry, registry_id)
            end
          end
        end

        ##
        # @return [Array<CatalogRow>]
        def local_catalog_rows
          LocalConfig.feeds.filter_map do |feed_name, feed_config|
            CatalogRow.from_local_feed(feed_name, feed_config)
          end
        end

        ##
        # @return [Hash{String => RegistryBundle}]
        def loaded_bundles
          @loaded_bundles ||= Config.precedence.to_h { |registry_id| [registry_id, load_bundle(registry_id)] }.compact
        end

        ##
        # @param registry_id [String]
        # @return [RegistryBundle, nil]
        def load_bundle(registry_id) # rubocop:disable Metrics/MethodLength
          entry = Config.entry(registry_id)
          directory = bundle_directory(entry)
          return nil unless directory && File.directory?(directory)
          return nil unless active_bundle_present?(directory)

          bundle = Html2rss::Registry::Bundle.load(
            directory,
            **trust_options_for(entry, directory)
          )
          registry_bundle = to_registry_bundle(registry_id, bundle)
          enforce_scrape_policy!(entry, registry_bundle)
          registry_bundle
        rescue Html2rss::Registry::Error => error
          raise Errors::LoadError, "Failed to load registry '#{registry_id}': #{error.message}"
        end

        ##
        # @param entry [Entry]
        # @param bundle_dir [String]
        # @return [Hash{Symbol => Object}] keyword args for {Html2rss::Registry::Bundle.load}
        def trust_options_for(entry, bundle_dir)
          case entry.mode
          in :path
            { trust: :integrity_only, public_keys: {} }
          in :sync
            if signed_bundle?(bundle_dir, entry)
              { trust: :signed, public_keys: entry.public_keys }
            else
              { trust: :integrity_only, public_keys: {} }
            end
          end
        end

        ##
        # @param bundle_dir [String]
        # @param entry [Entry]
        # @return [Boolean]
        def signed_bundle?(bundle_dir, entry)
          signature_path = File.join(bundle_dir, Html2rss::Registry::Manifest::SIGNATURE_FILE)
          File.file?(signature_path) && !entry.public_keys.empty?
        end

        ##
        # @param entry [Entry]
        # @param bundle [RegistryBundle]
        # @return [void]
        # @raise [Errors::LoadError] when a config channel URL violates the allowlist
        def enforce_scrape_policy!(entry, bundle) # rubocop:disable Metrics/CyclomaticComplexity
          allowed = entry.allowed_channel_domains
          return if allowed.nil? || allowed.empty?

          bundle.configs.each do |feed_id, config|
            channel_url = config.dig(:channel, :url)
            host = channel_host_for(channel_url)
            next if host && allowed.any? { |domain| channel_domain_allowed?(host, domain) }

            raise Errors::LoadError,
                  "Registry '#{entry.id}' config '#{feed_id}' channel.url host " \
                  "'#{host || channel_url}' is not allowed by allowed_channel_domains"
          end
        end

        ##
        # @param host [String]
        # @param allowed_domain [String]
        # @return [Boolean]
        def channel_domain_allowed?(host, allowed_domain)
          normalized_host = host.downcase
          normalized_domain = allowed_domain.downcase
          normalized_host == normalized_domain || normalized_host.end_with?(".#{normalized_domain}")
        end

        ##
        # @param channel_url [String, nil]
        # @return [String, nil]
        def channel_host_for(channel_url)
          return nil if channel_url.to_s.strip.empty?

          URI.parse(channel_url).host
        rescue URI::InvalidURIError
          nil
        end

        ##
        # @param registry_id [String]
        # @param bundle [Html2rss::Registry::Bundle::BundleData]
        # @return [RegistryBundle]
        def to_registry_bundle(registry_id, bundle)
          RegistryBundle.new(
            registry_id:,
            manifest: bundle.manifest,
            configs: bundle.configs,
            catalog_entries: bundle.catalog_entries
          )
        end

        ##
        # @param entry [Entry]
        # @return [String, nil]
        def bundle_directory(entry)
          return entry.path if entry.mode == :path

          Store.registry_dir(entry.id)
        end

        ##
        # @param directory [String]
        # @return [Boolean]
        def active_bundle_present?(directory)
          File.file?(File.join(directory, Html2rss::Registry::Manifest::MANIFEST_FILE))
        end

        ##
        # @param feed_id [String, Symbol]
        # @return [String]
        def normalize_feed_id(feed_id)
          feed_id.to_s.delete_prefix('/').sub(LocalConfig::FEED_EXTENSION_PATTERN, '')
        end

        ##
        # @param registry_id [String]
        # @return [Time, nil]
        def bundle_updated_at(registry_id)
          path = bundle_directory(Config.entry(registry_id))
          return nil unless path && File.directory?(path)

          manifest_path = File.join(path, Html2rss::Registry::Manifest::MANIFEST_FILE)
          return nil unless File.file?(manifest_path)

          File.mtime(manifest_path)
        end

        ##
        # @param feed_id [String]
        # @return [Hash{Symbol => Object}, nil]
        def local_config_for(feed_id)
          feed = LocalConfig.feeds[feed_id.to_sym] || LocalConfig.feeds[feed_id]
          return nil unless feed

          deep_dup(feed)
        rescue Html2rss::Web::LocalConfig::InvalidConfig, Html2rss::Web::LocalConfig::NotFound
          nil
        end

        ##
        # @param value [Object]
        # @return [Object]
        def deep_dup(value)
          case value
          when Hash
            value.transform_values { |entry| deep_dup(entry) }
          when Array
            value.map { |entry| deep_dup(entry) }
          else
            value
          end
        end
      end # rubocop:enable Metrics/ClassLength
    end
  end
end
