# frozen_string_literal: true

module Html2rss
  module Web
    module Registry
      ##
      # Fetches and stores signed registry bundles (network sync is expanded in Phase 4).
      module Sync
        OFFICIAL_RELEASE_URL = Config::OFFICIAL_RELEASE_URL

        SyncStatus = Data.define(:registry_id, :mode, :version, :updated_at, :sync_url, :last_error)

        class << self
          ##
          # Resolves the download URL for a sync-mode registry id.
          #
          # @param registry_id [String, Symbol]
          # @return [String]
          def sync_url_for(registry_id)
            entry = Config.entry(registry_id)
            raise Errors::SyncError, "Registry '#{registry_id}' is not sync-mode" unless entry.mode == :sync

            entry.sync_url
          end

          ##
          # Runs synchronization for a registry id.
          #
          # Phase 3 provides a minimal stub; Phase 4 adds fetch, verify, and store.
          #
          # @param registry_id [String, Symbol]
          # @return [SyncStatus]
          def run(registry_id:)
            entry = Config.entry(registry_id)
            if entry.mode == :path
              raise Errors::SyncError, "Registry '#{registry_id}' uses path mode; sync is not applicable"
            end

            raise Errors::SyncError, 'Registry network sync is not enabled until Phase 4'
          end

          ##
          # @param registry_id [String, Symbol, nil]
          # @return [Array<SyncStatus>]
          def status(registry_id: nil)
            rows = Index.current.status
            rows = rows.select { |row| row.id == registry_id.to_s } if registry_id
            rows.map { |row| sync_status_for(row) }
          end

          private

          ##
          # @param row [Index::StatusEntry]
          # @return [SyncStatus]
          def sync_status_for(row)
            entry = Config.entry(row.id)
            SyncStatus.new(
              registry_id: row.id,
              mode: row.sync_mode,
              version: row.version,
              updated_at: row.updated_at,
              sync_url: entry.sync_url,
              last_error: nil
            )
          end
        end
      end
    end
  end
end
