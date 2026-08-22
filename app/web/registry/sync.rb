# frozen_string_literal: true

require 'fileutils'

module Html2rss
  module Web
    module Registry
      ##
      # Fetches, verifies, and stores signed registry bundles.
      module Sync # rubocop:disable Metrics/ModuleLength
        SyncStatus = Data.define(
          :registry_id,
          :mode,
          :version,
          :staged_version,
          :updated_at,
          :sync_url,
          :last_error
        )

        @boot_mutex = Mutex.new
        @boot_started = false
        @timer_started = false

        class << self # rubocop:disable Metrics/ClassLength
          ##
          # Resolves the download URL for a sync-mode registry id.
          #
          # @param registry_id [String, Symbol]
          # @return [String]
          def sync_url_for(registry_id)
            entry = Config.entry(registry_id)
            raise Errors::SyncError, "Registry '#{registry_id}' is not sync-mode" unless entry.mode == :sync

            SyncUrlResolver.resolve(entry)
          end

          ##
          # Runs synchronization for a registry id.
          #
          # @param registry_id [String, Symbol]
          # @param dry_run [Boolean] when true, verify without swapping the active bundle
          # @return [SyncStatus]
          def run(registry_id:, dry_run: false)
            SyncCoordinator.run(registry_id) { run!(registry_id:, dry_run:) }
          end

          ##
          # Promotes a verified staging bundle to the active registry directory.
          #
          # @param registry_id [String, Symbol]
          # @return [SyncStatus]
          def promote_staged!(registry_id:)
            SyncCoordinator.run(registry_id) { promote_staged_bundle!(registry_id:) }
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [Array<SyncStatus>]
          def status(registry_id: nil)
            rows = Index.current.status
            rows = rows.select { |row| row.id == registry_id.to_s } if registry_id
            rows.map { |row| sync_status_for(row) }
          end

          ##
          # Seeds sync-mode registries and optionally syncs on boot.
          #
          # @return [void]
          def boot! # rubocop:disable Metrics/MethodLength
            @boot_mutex.synchronize do
              return if @boot_started

              @boot_started = true
            end
            return if skip_boot?

            Config.precedence.each do |registry_id|
              entry = Config.entry(registry_id)
              next unless entry.mode == :sync

              seed_registry!(registry_id)
              schedule_boot_sync!(registry_id) if boot_sync?(registry_id)
            end

            start_background_timer!
          end

          ##
          # Starts a jittered background sync loop when enabled.
          #
          # @return [void]
          def start_background_timer! # rubocop:disable Metrics/MethodLength
            interval_hours = Integer(ENV.fetch('REGISTRY_SYNC_INTERVAL_HOURS', '24'))
            return if interval_hours <= 0

            @boot_mutex.synchronize do
              return if @timer_started

              @timer_started = true
            end

            Thread.new do # rubocop:disable ThreadSafety/NewThread -- background registry refresh by design
              sleep(background_jitter_seconds(interval_hours))
              loop do
                sync_all!
                sleep(interval_hours * 3600)
              end
            end
          end

          ##
          # @return [Integer] process exit code for CLI use (0 ok, 1 when sync registries lack bundles)
          def cli_exit_code
            unusable_sync_registries.empty? ? 0 : 1
          end

          ##
          # @return [Array<String>] sync-mode registry ids without a usable on-disk bundle
          def unusable_sync_registries
            Config.precedence.filter_map do |registry_id|
              entry = Config.entry(registry_id)
              next unless entry.mode == :sync
              next if Store.bundle_present?(registry_id)

              registry_id
            end
          end

          private

          ##
          # @param registry_id [String, Symbol]
          # @param dry_run [Boolean]
          # @return [SyncStatus]
          def run!(registry_id:, dry_run:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
            entry = Config.entry(registry_id)
            if entry.mode == :path
              raise Errors::SyncError, "Registry '#{registry_id}' uses path mode; sync is not applicable"
            end

            staging_root = nil
            download_url = SyncUrlResolver.resolve(entry)
            staging_root, staged_dir = fetch_and_verify!(entry, download_url)
            unless dry_run
              if entry.sync_policy.auto_promote
                activate_bundle!(registry_id, staged_dir)
              else
                Store.stage_bundle!(registry_id, staged_dir)
                record_success!(registry_id, promoted: false)
              end
            end
            sync_status_for(Index.current.status.find { |row| row.id == registry_id.to_s })
          rescue StandardError => error
            record_failure!(registry_id, error) unless dry_run
            raise
          ensure
            FileUtils.rm_rf(staging_root) if staging_root
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [SyncStatus]
          def promote_staged_bundle!(registry_id:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
            entry = Config.entry(registry_id)
            if entry.mode == :path
              raise Errors::SyncError, "Registry '#{registry_id}' uses path mode; promote is not applicable"
            end
            unless Store.staged_present?(registry_id)
              raise Errors::SyncError, "Registry '#{registry_id}' has no staged bundle"
            end

            previous_bundle = Index.current.bundle_for(registry_id)
            Store.promote_staged!(registry_id)
            Index.reload!
            report_catalog_change!(registry_id, previous_bundle)
            record_success!(registry_id, promoted: true)
            Observability.emit(
              event_name: 'registry.promote_staged',
              outcome: 'success',
              details: {
                registry_id: registry_id.to_s,
                version: Index.current.status.find { |row| row.id == registry_id.to_s }&.version
              }
            )
            sync_status_for(Index.current.status.find { |row| row.id == registry_id.to_s })
          end

          ##
          # @param registry_id [String, Symbol]
          # @param staged_dir [String]
          # @return [void]
          def activate_bundle!(registry_id, staged_dir)
            previous_bundle = Index.current.bundle_for(registry_id)
            Store.swap!(registry_id, staged_dir)
            Index.reload!
            report_catalog_change!(registry_id, previous_bundle)
            record_success!(registry_id, promoted: true)
          end

          ##
          # @param registry_id [String, Symbol]
          # @param previous_bundle [Index::RegistryBundle, nil]
          # @return [void]
          def report_catalog_change!(registry_id, previous_bundle)
            new_bundle = Index.current.bundle_for(registry_id)
            return unless new_bundle

            CatalogChangeReporter.report!(
              registry_id: registry_id.to_s,
              previous_bundle:,
              new_bundle:
            )
          end

          ##
          # @return [Boolean]
          def skip_boot?
            ENV.fetch('RACK_ENV', 'development') == 'test'
          end

          ##
          # @param registry_id [String]
          # @return [void]
          def seed_registry!(registry_id) # rubocop:disable Metrics/MethodLength
            seed_path = Store.seed_path_for(registry_id)
            return unless File.directory?(seed_path)

            seeded = Store.seed_if_empty!(registry_id, seed_path:)
            Index.reload! if seeded
          rescue Errors::LoadError => error
            AppLogger.logger.warn(
              {
                component: 'registry',
                event_name: 'registry.seed',
                outcome: 'failure',
                registry_id:,
                error: error.message
              }.to_json
            )
          end

          ##
          # @param registry_id [String]
          # @return [Boolean]
          def boot_sync?(registry_id)
            ENV.fetch('REGISTRY_SYNC_ON_BOOT', 'false') == 'true' || !Store.bundle_present?(registry_id)
          end

          ##
          # @param registry_id [String]
          # @return [void]
          def schedule_boot_sync!(registry_id)
            Thread.new { run(registry_id:) } # rubocop:disable ThreadSafety/NewThread -- non-blocking first boot
          rescue StandardError
            nil
          end

          ##
          # @return [void]
          def sync_all!
            Config.precedence.each do |registry_id|
              entry = Config.entry(registry_id)
              next unless entry.mode == :sync

              run(registry_id:)
            rescue StandardError
              nil
            end
          end

          ##
          # @param interval_hours [Integer]
          # @return [Numeric]
          def background_jitter_seconds(interval_hours)
            max_jitter = [(interval_hours * 3600 * BACKGROUND_JITTER_FRACTION).to_i, 1].max
            rand(max_jitter)
          end

          BACKGROUND_JITTER_FRACTION = 0.1
          private_constant :BACKGROUND_JITTER_FRACTION

          ##
          # @param entry [Entry]
          # @param download_url [String]
          # @return [Array(String, String)] staging root and verified bundle directory
          def fetch_and_verify!(entry, download_url) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
            tarball = SyncFetcher.fetch!(download_url)
            staging_root = Dir.mktmpdir('registry-sync-')
            staged_dir = File.join(staging_root, 'bundle')
            tarball_path = File.join(staging_root, 'download.tar.gz')
            FileUtils.mkdir_p(staged_dir)
            File.binwrite(tarball_path, tarball)

            File.open(tarball_path, 'rb') do |io|
              Html2rss::Registry::Archive.extract!(io, into: staged_dir)
            end

            Html2rss::Registry::Verifier.verify!(
              staged_dir,
              trust: :signed,
              public_keys: entry.public_keys
            )
            enforce_max_version!(entry, staged_dir)
            [staging_root, staged_dir]
          rescue Html2rss::Registry::VerificationError => error
            log_signature_failure!(entry.id, error.message) if signature_failure?(error)
            raise Errors::SyncError, error.message
          rescue Html2rss::Registry::ArchiveError => error
            raise Errors::SyncError, error.message
          end

          ##
          # @param error [Html2rss::Registry::VerificationError]
          # @return [Boolean]
          def signature_failure?(error)
            error.message.match?(/signature|public_key_id/i)
          end

          ##
          # @param registry_id [String]
          # @param message [String]
          # @return [void]
          def log_signature_failure!(registry_id, message)
            SecurityLogger.log_registry_signature_failure(registry_id, message)
          end

          ##
          # @param entry [Entry]
          # @param staged_dir [String]
          # @return [void]
          def enforce_max_version!(entry, staged_dir)
            manifest = read_manifest!(staged_dir)
            max_version = entry.sync_policy.max_version
            return unless max_version

            return unless VersionGate.exceeds_max?(manifest.version, max_version)

            raise Errors::SyncError,
                  "Registry '#{entry.id}' manifest version '#{manifest.version}' exceeds max_version '#{max_version}'"
          end

          ##
          # @param staged_dir [String]
          # @return [Html2rss::Registry::Manifest]
          def read_manifest!(staged_dir)
            Html2rss::Registry::Manifest.parse(
              File.read(File.join(staged_dir, Html2rss::Registry::Manifest::MANIFEST_FILE))
            )
          end

          ##
          # @param registry_id [String]
          # @param promoted [Boolean]
          # @return [void]
          def record_success!(registry_id, promoted:) # rubocop:disable Metrics/MethodLength
            Store.write_sync_state!(registry_id, last_error: nil)
            row = Index.current.status.find { |entry| entry.id == registry_id.to_s }
            Observability.emit(
              event_name: 'registry.sync',
              outcome: 'success',
              details: {
                registry_id:,
                version: row&.version,
                staged_version: Store.staged_version(registry_id),
                promoted:
              }
            )
          end

          ##
          # @param registry_id [String]
          # @param error [StandardError]
          # @return [void]
          def record_failure!(registry_id, error)
            Store.write_sync_state!(registry_id, last_error: error.message)
            Observability.emit(
              event_name: 'registry.sync',
              outcome: 'failure',
              details: { registry_id:, error: error.message },
              level: :warn
            )
          end

          ##
          # @param row [Index::StatusEntry]
          # @return [SyncStatus]
          def sync_status_for(row) # rubocop:disable Metrics/MethodLength
            entry = Config.entry(row.id)
            state = Store.sync_state(row.id)
            SyncStatus.new(
              registry_id: row.id,
              mode: row.sync_mode,
              version: row.version,
              staged_version: Store.staged_version(row.id),
              updated_at: row.updated_at,
              sync_url: entry.mode == :sync ? SyncUrlResolver.resolve(entry) : nil,
              last_error: state.last_error
            )
          end
        end # rubocop:enable Metrics/ClassLength
      end # rubocop:enable Metrics/ModuleLength
    end
  end
end
