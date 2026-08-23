# frozen_string_literal: true

require 'fileutils'

module Html2rss
  module Web
    module Registry
      ##
      # Fetches, verifies, and stores signed registry bundles.
      module Sync # rubocop:disable Metrics/ModuleLength
        @boot_mutex = Mutex.new
        @boot_started = false
        @timer_started = false
        REGISTRY_MUTEXES = Hash.new { |mutexes, registry_id| mutexes[registry_id] = Mutex.new }

        class << self # rubocop:disable Metrics/ClassLength
          ##
          # @param registry_id [String, Symbol]
          # @return [String]
          def sync_url_for(registry_id)
            definition = Config.entry(registry_id)
            raise Errors::SyncError, "Registry '#{registry_id}' is path mode" if definition.mode == :path

            ChannelResolver.resolve(definition)
          end

          ##
          # @param registry_id [String, Symbol]
          # @param dry_run [Boolean]
          # @return [Status]
          def run(registry_id:, dry_run: false)
            REGISTRY_MUTEXES[registry_id.to_s].synchronize { run_sync!(registry_id:, dry_run:) }
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [Status]
          def promote_staged!(registry_id:) # rubocop:disable Metrics/MethodLength
            REGISTRY_MUTEXES[registry_id.to_s].synchronize do
              definition = Config.entry(registry_id)
              raise Errors::SyncError, "Registry '#{registry_id}' is path mode" if definition.mode == :path
              unless Store.staged_present?(registry_id)
                raise Errors::SyncError,
                      "Registry '#{registry_id}' has no staged bundle"
              end

              previous_bundle = Index.current.bundle_for(registry_id)
              Store.promote_staged!(registry_id)
              Index.reload!
              report_catalog_change!(registry_id, previous_bundle)
              Store.write_sync_state!(registry_id, last_error: nil)
              Index.current.status_entry_for(registry_id)
            end
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [Array<Status>]
          def status(registry_id: nil)
            rows = Index.current.status
            registry_id ? rows.select { it.id == registry_id.to_s } : rows
          end

          ##
          # @return [void]
          def boot! # rubocop:disable Metrics/MethodLength
            @boot_mutex.synchronize do
              return if @boot_started

              @boot_started = true
            end
            return if ENV.fetch('RACK_ENV', 'development') == 'test'

            Config.precedence.each do |id|
              definition = Config.entry(id)
              next unless definition.mode == :sync

              seed_registry!(id)
              Thread.new { run(registry_id: id) } if boot_sync?(id) # rubocop:disable ThreadSafety/NewThread
            end

            start_background_timer!
          end

          ##
          # @return [void]
          def start_background_timer! # rubocop:disable Metrics/MethodLength
            interval = Integer(ENV.fetch('REGISTRY_SYNC_INTERVAL_HOURS', '24'))
            return if interval <= 0

            @boot_mutex.synchronize do
              return if @timer_started

              @timer_started = true
            end

            Thread.new do # rubocop:disable ThreadSafety/NewThread
              loop do
                sleep(interval * 3600)
                Config.precedence.each { |id| run(registry_id: id) if Config.entry(id).mode == :sync rescue nil } # rubocop:disable Style/RescueModifier
              end
            end
          end

          private

          def run_sync!(registry_id:, dry_run:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
            definition = Config.entry(registry_id)
            raise Errors::SyncError, "Registry '#{registry_id}' is path mode" if definition.mode == :path

            staging_root = Dir.mktmpdir('registry-sync-')
            staged_dir = File.join(staging_root, 'bundle')
            FileUtils.mkdir_p(staged_dir)

            download_url = ChannelResolver.resolve(definition)
            tarball = HttpTransport.fetch!(download_url)
            File.binwrite(File.join(staging_root, 'download.tar.gz'), tarball)

            File.open(File.join(staging_root, 'download.tar.gz'), 'rb') do |io|
              Html2rss::Registry::Archive.extract!(io, into: staged_dir)
            end

            manifest = Html2rss::Registry::Verifier.verify!(staged_dir, trust: :signed,
                                                                        public_keys: definition.public_keys)
            enforce_max_version!(definition, manifest)

            unless dry_run
              if definition.sync_policy.auto_promote
                previous = Index.current.bundle_for(registry_id)
                Store.swap!(registry_id, staged_dir)
                Index.reload!
                report_catalog_change!(registry_id, previous)
              else
                Store.stage_bundle!(registry_id, staged_dir)
              end
              Store.write_sync_state!(registry_id, last_error: nil)
            end

            Index.current.status_entry_for(registry_id)
          rescue Html2rss::Registry::VerificationError => error
            log_signature_failure!(registry_id, error.message) if error.message.match?(/signature|public_key_id/i)
            Store.write_sync_state!(registry_id, last_error: error.message) unless dry_run
            raise Errors::SyncError, error.message
          rescue Html2rss::Registry::ArchiveError => error
            Store.write_sync_state!(registry_id, last_error: error.message) unless dry_run
            raise Errors::SyncError, error.message
          rescue StandardError => error
            Store.write_sync_state!(registry_id, last_error: error.message) unless dry_run
            raise
          ensure
            FileUtils.rm_rf(staging_root) if staging_root
          end

          def log_signature_failure!(registry_id, message)
            SecurityLogger.log_registry_signature_failure(registry_id, message)
          rescue StandardError
            nil
          end

          def enforce_max_version!(definition, manifest)
            max = definition.sync_policy.max_version
            return if max.nil? || max.empty?
            return unless Html2rss::Registry::Manifest.exceeds_max?(manifest.version, max)

            raise Errors::SyncError, "Manifest version '#{manifest.version}' exceeds max_version '#{max}'"
          end

          def report_catalog_change!(registry_id, previous) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
            current = Index.current.bundle_for(registry_id)
            return unless current

            prev_ids = previous ? Set.new(previous.catalog_entries.map(&:id)) : Set.new
            curr_ids = Set.new(current.catalog_entries.map(&:id))
            added = (curr_ids - prev_ids).to_a.sort
            removed = (prev_ids - curr_ids).to_a.sort
            return if added.empty? && removed.empty? && previous&.manifest&.version == current.manifest.version

            Observability.emit(
              event_name: 'registry.catalog_changed',
              outcome: 'success',
              level: :warn,
              details: { registry_id:, version: current.manifest.version, added_count: added.size,
                         removed_count: removed.size }
            )
          end

          def seed_registry!(registry_id)
            seed_path = Store.seed_path_for(registry_id)
            Index.reload! if File.directory?(seed_path) && Store.seed_if_empty!(registry_id, seed_path:)
          rescue StandardError
            nil
          end

          def boot_sync?(registry_id)
            ENV.fetch('REGISTRY_SYNC_ON_BOOT', 'false') == 'true' || !Store.bundle_present?(registry_id)
          end
        end
      end
    end
  end
end
