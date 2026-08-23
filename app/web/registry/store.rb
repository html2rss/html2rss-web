# frozen_string_literal: true

require 'fileutils'
require 'json'

module Html2rss
  module Web
    module Registry
      ##
      # Transactional storage engine for registry bundles and sync state.
      module Store # rubocop:disable Metrics/ModuleLength
        DEFAULT_DATA_ROOT = 'tmp/registry-data'
        DEFAULT_SEED_ROOT = '/app/registries/seed'
        SYNC_STATE_FILE = '.sync-state.json'

        ##
        # Immutable registry sync state.
        SyncState = Data.define(:last_error, :last_sync_at)

        class << self
          ##
          # @return [String]
          def data_root
            File.expand_path(ENV.fetch('REGISTRY_DATA_ROOT', DEFAULT_DATA_ROOT))
          end

          ##
          # @return [String]
          def seed_root
            File.expand_path(ENV.fetch('REGISTRY_SEED_ROOT', DEFAULT_SEED_ROOT))
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [String]
          def registry_dir(registry_id)
            File.join(data_root, registry_id.to_s)
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [String]
          def staging_dir(registry_id)
            File.join(registry_dir(registry_id), '.staging')
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [Boolean]
          def bundle_present?(registry_id)
            bundle_present_at?(registry_dir(registry_id))
          end

          ##
          # @param path [String]
          # @return [Boolean]
          def bundle_present_at?(path)
            File.file?(File.join(path, Html2rss::Registry::Manifest::MANIFEST_FILE))
          end

          ##
          # @param registry_id [String, Symbol]
          # @param staged_dir [String]
          # @return [String]
          def stage_bundle!(registry_id, staged_dir)
            target = staging_dir(registry_id)
            FileUtils.mkdir_p(registry_dir(registry_id))
            FileUtils.rm_rf(target)
            FileUtils.cp_r(staged_dir, target)
            target
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [Boolean]
          def staged_present?(registry_id)
            bundle_present_at?(staging_dir(registry_id))
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [String, nil]
          def staged_version(registry_id)
            manifest_version_at(staging_dir(registry_id))
          end

          ##
          # Atomically swaps a directory into the active registry directory.
          #
          # @param registry_id [String, Symbol]
          # @param source_dir [String]
          # @return [String] active directory
          def swap!(registry_id, source_dir)
            target = registry_dir(registry_id)
            FileUtils.mkdir_p(File.dirname(target))
            backup = "#{target}.backup.#{Process.pid}"
            FileUtils.mv(target, backup) if File.exist?(target)
            FileUtils.cp_r(source_dir, target)
            target
          ensure
            FileUtils.rm_rf(backup) if backup
          end

          ##
          # Promotes staging directory to active directory.
          #
          # @param registry_id [String, Symbol]
          # @return [String] active directory
          def promote_staged!(registry_id)
            staged = staging_dir(registry_id)
            raise Errors::LoadError, "No staged bundle for '#{registry_id}'" unless staged_present?(registry_id)

            temp_root = Dir.mktmpdir('registry-promote-')
            temp_staged = File.join(temp_root, 'bundle')
            FileUtils.mv(staged, temp_staged)

            swap!(registry_id, temp_staged)
            registry_dir(registry_id)
          ensure
            FileUtils.rm_rf(temp_root) if temp_root
          end

          ##
          # Copies seed bundle into data root if active bundle is missing.
          #
          # @param registry_id [String, Symbol]
          # @param seed_path [String]
          # @return [Boolean]
          def seed_if_empty!(registry_id, seed_path:) # rubocop:disable Naming/PredicateMethod
            return false if bundle_present?(registry_id)
            raise Errors::LoadError, "Seed bundle missing: #{seed_path}" unless File.directory?(seed_path)

            target = registry_dir(registry_id)
            FileUtils.mkdir_p(File.dirname(target))
            FileUtils.cp_r(seed_path, target)
            true
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [SyncState]
          def sync_state(registry_id)
            raw = read_sync_state.fetch(registry_id.to_s, {})
            last_sync = raw['last_sync_at']
            SyncState.new(
              last_error: raw['last_error'],
              last_sync_at: last_sync ? Time.parse(last_sync) : nil
            )
          end

          ##
          # @param registry_id [String, Symbol]
          # @param last_error [String, nil]
          # @param last_sync_at [Time, nil]
          # @return [void]
          def write_sync_state!(registry_id, last_error:, last_sync_at: Time.now.utc)
            state = read_sync_state
            state[registry_id.to_s] = {
              'last_error' => last_error,
              'last_sync_at' => last_sync_at&.iso8601
            }.compact
            FileUtils.mkdir_p(data_root)
            File.write(sync_state_path, JSON.generate(state))
          end

          ##
          # @param path [String, nil]
          # @return [Time, nil]
          def manifest_mtime(path)
            return nil unless path && File.directory?(path)

            manifest_file = File.join(path, Html2rss::Registry::Manifest::MANIFEST_FILE)
            File.file?(manifest_file) ? File.mtime(manifest_file) : nil
          end

          private

          def sync_state_path
            File.join(data_root, SYNC_STATE_FILE)
          end

          def read_sync_state
            return {} unless File.file?(sync_state_path)

            JSON.parse(File.read(sync_state_path))
          rescue JSON::ParserError
            {}
          end

          def manifest_version_at(path)
            manifest_file = File.join(path, Html2rss::Registry::Manifest::MANIFEST_FILE)
            return nil unless File.file?(manifest_file)

            Html2rss::Registry::Manifest.parse(File.read(manifest_file)).version
          rescue Html2rss::Registry::ManifestError
            nil
          end
        end
      end
    end
  end
end
