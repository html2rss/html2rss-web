# frozen_string_literal: true

require 'fileutils'

module Html2rss
  module Web
    module Registry
      ##
      # Manages on-disk registry bundle directories under {data_root}.
      module Store
        DEFAULT_DATA_ROOT = 'tmp/registry-data'

        class << self
          ##
          # @return [String] root directory for extracted registry bundles
          def data_root
            File.expand_path(ENV.fetch('REGISTRY_DATA_ROOT', DEFAULT_DATA_ROOT))
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [String] active bundle directory for a registry id
          def registry_dir(registry_id)
            File.join(data_root, registry_id.to_s)
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
            return false if bundle_present?(target)

            raise Errors::LoadError, "Seed bundle missing: #{seed_path}" unless File.directory?(seed_path)

            FileUtils.mkdir_p(File.dirname(target))
            FileUtils.cp_r(seed_path, target)
            true
          end

          private

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
          def bundle_present?(path)
            File.directory?(path) && !Dir.empty?(path)
          end
        end
      end
    end
  end
end
