# frozen_string_literal: true

require 'fileutils'
require 'json'

module Html2rss
  module Web
    module Registry
      ##
      # Manages on-disk registry bundle directories under {data_root}.
      module Store # rubocop:disable Metrics/ModuleLength
        DEFAULT_DATA_ROOT = 'tmp/registry-data'
        DEFAULT_SEED_ROOT = '/app/registries/seed'
        SYNC_STATE_FILE = '.sync-state.json'

        SyncState = Data.define(:last_error, :last_sync_at)

        class << self # rubocop:disable Metrics/ClassLength
          ##
          # @return [String] root directory for extracted registry bundles
          def data_root
            File.expand_path(ENV.fetch('REGISTRY_DATA_ROOT', DEFAULT_DATA_ROOT))
          end

          ##
          # @return [String] root directory for image-shipped seed bundles
          def seed_root
            File.expand_path(ENV.fetch('REGISTRY_SEED_ROOT', DEFAULT_SEED_ROOT))
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [String] active bundle directory for a registry id
          def registry_dir(registry_id)
            File.join(data_root, registry_id.to_s)
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [String] seed bundle directory for a registry id
          def seed_path_for(registry_id)
            File.join(seed_root, registry_id.to_s)
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [Boolean]
          def bundle_present?(registry_id)
            bundle_present_at?(registry_dir(registry_id))
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [String] verified staging directory for a registry id
          def staging_dir(registry_id)
            File.join(registry_dir(registry_id), '.staging')
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
          # Writes a verified bundle to the registry staging directory.
          #
          # @param registry_id [String, Symbol]
          # @param staged_dir [String] verified bundle directory to stage
          # @return [String] staging directory
          def stage_bundle!(registry_id, staged_dir)
            raise Errors::LoadError, "Staged bundle missing: #{staged_dir}" unless File.directory?(staged_dir)

            target = staging_dir(registry_id)
            parent = registry_dir(registry_id)
            FileUtils.mkdir_p(parent)

            backup = "#{target}.backup.#{Process.pid}"
            promote_bundle!(staged_dir, target, backup)
            target
          end

          ##
          # Promotes a verified staging bundle to the active registry directory.
          #
          # @param registry_id [String, Symbol]
          # @return [String] active bundle directory
          def promote_staged!(registry_id) # rubocop:disable Metrics/MethodLength
            staged = staging_dir(registry_id)
            raise Errors::LoadError, "No staged bundle for '#{registry_id}'" unless staged_present?(registry_id)

            temp_root = Dir.mktmpdir('registry-promote-')
            temp_staged = File.join(temp_root, 'bundle')
            FileUtils.mv(staged, temp_staged)

            active = registry_dir(registry_id)
            backup = "#{active}.backup.#{Process.pid}"
            promote_bundle!(temp_staged, active, backup)
            active
          ensure
            FileUtils.rm_rf(temp_root) if temp_root
          end

          ##
          # Atomically replaces the active bundle directory for a registry id.
          #
          # @param registry_id [String, Symbol]
          # @param staged_dir [String] verified bundle directory to promote
          # @return [String] promoted bundle directory
          def swap!(registry_id, staged_dir)
            raise Errors::LoadError, "Staged bundle missing: #{staged_dir}" unless File.directory?(staged_dir)

            target = registry_dir(registry_id)
            parent = File.dirname(target)
            FileUtils.mkdir_p(parent)

            backup = "#{target}.backup.#{Process.pid}"
            promote_bundle!(staged_dir, target, backup)
            target
          end

          ##
          # Copies a seed bundle into the data root when no active bundle exists.
          #
          # @param registry_id [String, Symbol]
          # @param seed_path [String] bundle directory to copy
          # @return [Boolean] true when a seed copy was performed
          def seed_if_empty!(registry_id, seed_path:) # rubocop:disable Naming/PredicateMethod
            target = registry_dir(registry_id)
            return false if bundle_present?(registry_id)

            raise Errors::LoadError, "Seed bundle missing: #{seed_path}" unless File.directory?(seed_path)

            FileUtils.mkdir_p(File.dirname(target))
            FileUtils.cp_r(seed_path, target)
            true
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [SyncState]
          def sync_state(registry_id)
            raw = read_sync_state.fetch(registry_id.to_s, {})
            SyncState.new(
              last_error: raw['last_error'],
              last_sync_at: parse_sync_time(raw['last_sync_at'])
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

          private

          ##
          # @return [String]
          def sync_state_path
            File.join(data_root, SYNC_STATE_FILE)
          end

          ##
          # @return [Hash{String => Hash{String => Object}}]
          def read_sync_state
            return {} unless File.file?(sync_state_path)

            JSON.parse(File.read(sync_state_path))
          rescue JSON::ParserError
            {}
          end

          ##
          # @param staged_dir [String]
          # @param target [String]
          # @param backup [String]
          # @return [void]
          def promote_bundle!(staged_dir, target, backup)
            FileUtils.rm_rf(backup)
            FileUtils.mv(target, backup) if File.exist?(target)
            FileUtils.mv(staged_dir, target)
          rescue StandardError
            FileUtils.rm_rf(target)
            FileUtils.mv(backup, target) if File.exist?(backup)
            raise
          ensure
            FileUtils.rm_rf(backup)
          end

          ##
          # @param path [String]
          # @return [Boolean]
          def bundle_present_at?(path)
            File.file?(File.join(path, Html2rss::Registry::Manifest::MANIFEST_FILE))
          end

          ##
          # @param path [String]
          # @return [String, nil]
          def manifest_version_at(path)
            return nil unless bundle_present_at?(path)

            manifest = Html2rss::Registry::Manifest.parse(
              File.read(File.join(path, Html2rss::Registry::Manifest::MANIFEST_FILE))
            )
            manifest.version
          rescue Html2rss::Registry::ManifestError
            nil
          end

          ##
          # @param value [String, nil]
          # @return [Time, nil]
          def parse_sync_time(value)
            return nil if value.to_s.empty?

            Time.parse(value)
          end
        end
      end
    end
  end
end
