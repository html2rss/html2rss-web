# frozen_string_literal: true

require 'fileutils'
require 'json'

module Html2rss
  module Web
    module Registry
      ##
      # Manages on-disk registry bundle directories under {data_root}.
      module Store
        DEFAULT_DATA_ROOT = 'tmp/registry-data'
        DEFAULT_SEED_ROOT = '/app/registries/seed'
        SYNC_STATE_FILE = '.sync-state.json'

        class << self
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
          # @return [Hash{Symbol => Object}]
          def sync_state(registry_id)
            read_sync_state.fetch(registry_id.to_s, {})
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
            File.directory?(path) && !Dir.empty?(path)
          end
        end
      end
    end
  end
end
