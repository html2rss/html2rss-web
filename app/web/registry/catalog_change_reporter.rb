# frozen_string_literal: true

module Html2rss
  module Web
    module Registry
      ##
      # Reports catalog diffs after a registry bundle is promoted to active.
      module CatalogChangeReporter
        module_function

        ##
        # @param registry_id [String]
        # @param previous_bundle [Index::RegistryBundle, nil]
        # @param new_bundle [Index::RegistryBundle]
        # @return [void]
        def report!(registry_id:, previous_bundle:, new_bundle:)
          diff = build_diff(previous_bundle, new_bundle)
          return if diff.empty?

          emit_observability!(registry_id, diff)
          emit_security!(registry_id, diff) if diff[:added].any? || diff[:removed].any?
        end

        ##
        # @param previous_bundle [Index::RegistryBundle, nil]
        # @param new_bundle [Index::RegistryBundle]
        # @return [Hash{Symbol => Object}]
        def build_diff(previous_bundle, new_bundle) # rubocop:disable Metrics/MethodLength
          previous_version = previous_bundle&.manifest&.version
          new_version = new_bundle.manifest.version
          previous_ids = catalog_ids(previous_bundle)
          new_ids = catalog_ids(new_bundle)
          added = new_ids - previous_ids
          removed = previous_ids - new_ids

          return {} if previous_version == new_version && added.empty? && removed.empty?

          {
            previous_version:,
            version: new_version,
            added:,
            removed:
          }
        end

        ##
        # @param registry_id [String]
        # @param diff [Hash{Symbol => Object}]
        # @return [void]
        def emit_observability!(registry_id, diff) # rubocop:disable Metrics/MethodLength
          Observability.emit(
            event_name: 'registry.catalog_changed',
            outcome: 'success',
            level: :warn,
            details: {
              registry_id:,
              version: diff[:version],
              previous_version: diff[:previous_version],
              added_count: diff[:added].size,
              removed_count: diff[:removed].size,
              added_ids: diff[:added].sort,
              removed_ids: diff[:removed].sort
            }
          )
        end

        ##
        # @param registry_id [String]
        # @param diff [Hash{Symbol => Object}]
        # @return [void]
        def emit_security!(registry_id, diff)
          SecurityLogger.log_registry_catalog_changed(
            registry_id,
            version: diff[:version],
            previous_version: diff[:previous_version],
            added_count: diff[:added].size,
            removed_count: diff[:removed].size,
            added_ids: diff[:added].sort,
            removed_ids: diff[:removed].sort
          )
        end

        ##
        # @param bundle [Index::RegistryBundle, nil]
        # @return [Array<String>]
        def catalog_ids(bundle)
          return [] unless bundle

          bundle.catalog_entries.map(&:id)
        end

        private_class_method :build_diff, :emit_observability!, :emit_security!, :catalog_ids
      end
    end
  end
end
