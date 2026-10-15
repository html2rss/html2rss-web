# frozen_string_literal: true

require 'fileutils'
require 'yaml'

module Html2rss
  module Web
    module Registry
      ##
      # Mutates the built-in path-mode +local+ registry bundle.
      #
      # Validates each feed with +Html2rss::Config::Validator+, upserts by
      # +registry.id+, and atomically replaces the on-disk bundle directory.
      module LocalBundle # rubocop:disable Metrics/ModuleLength
        REGISTRY_ID = 'local'
        PUBLIC_KEY_ID = 'local'
        CONFIGS_PREFIX = Html2rss::Registry::BundleRelativePath::CONFIGS_PREFIX

        ##
        # Outcome of a successful {.add!}.
        Result = Data.define(:ids, :path)

        class << self
          ##
          # Adds one feed YAML file or every +.yml+/+.yaml+ file under a directory
          # into the local registry bundle. Directory adds are all-or-nothing.
          #
          # @param source [String] path to a feed file or directory of feed files
          # @return [Result]
          def add!(source)
            definition = local_definition!
            feeds = load_and_validate_sources!(source)
            install_bundle!(definition.path, feeds)
            Index.reload!
            Result.new(ids: feeds.keys.sort, path: definition.path)
          end

          private

          ##
          # @return [Definition]
          def local_definition!
            definition = Config.entry(REGISTRY_ID)
            unless definition.mode == :path && definition.path
              raise Errors::ConfigError, "Registry '#{REGISTRY_ID}' must be path mode"
            end

            definition
          end

          ##
          # @param source [String]
          # @return [Hash{String => String}] registry.id => YAML contents
          def load_and_validate_sources!(source)
            path = File.expand_path(source)
            raise Errors::LoadError, "Path not found: #{source}" unless File.exist?(path)

            paths = source_files(path)
            raise Errors::LoadError, "No YAML feed files found in #{source}" if paths.empty?

            paths.each_with_object({}) do |file_path, memo|
              id, contents = validate_feed_file!(file_path)
              raise Errors::LoadError, "Duplicate registry.id '#{id}' in add set" if memo.key?(id)

              memo[id] = contents
            end
          end

          ##
          # @param path [String]
          # @return [Array<String>]
          def source_files(path)
            if File.directory?(path)
              Dir[File.join(path, '**', '*.{yml,yaml}')]
            else
              [path]
            end
          end

          ##
          # @param file_path [String]
          # @return [Array<(String, String)>] registry.id and file contents
          def validate_feed_file!(file_path) # rubocop:disable Metrics/MethodLength
            contents = File.read(file_path)
            config = YAML.safe_load(contents, symbolize_names: true)
            raise Errors::LoadError, "Invalid YAML in #{file_path}" unless config.is_a?(Hash)

            result = Html2rss::Config::Validator.new.call(config)
            unless result.success?
              message = result.errors(full: true).map(&:text).join('; ')
              raise Errors::LoadError, "Invalid feed config #{file_path}: #{message}"
            end

            id = config.dig(:registry, :id).to_s
            raise Errors::LoadError, "Missing registry.id in #{file_path}" if id.empty?

            [id, contents]
          end

          ##
          # @param target [String]
          # @param feeds [Hash{String => String}]
          # @return [void]
          def install_bundle!(target, feeds)
            FileUtils.mkdir_p(File.dirname(target))
            staging = sibling_staging_dir(target)
            begin
              assemble_bundle!(staging, target, feeds)
              Html2rss::Registry::Bundle.load(staging, trust: :integrity_only)
              Store.replace_directory!(staging, target)
            ensure
              FileUtils.rm_rf(staging)
            end
          end

          ##
          # @param staging [String]
          # @param existing_path [String]
          # @param feeds [Hash{String => String}]
          # @return [void]
          def assemble_bundle!(staging, existing_path, feeds)
            merged = existing_feed_contents(existing_path).merge(feeds)
            raise Errors::LoadError, 'Local registry bundle would be empty' if merged.empty?

            relative_paths = write_feed_files!(staging, merged)
            write_manifest!(staging, relative_paths)
          end

          ##
          # @param staging [String]
          # @param feeds [Hash{String => String}]
          # @return [Array<String>]
          def write_feed_files!(staging, feeds)
            feeds.keys.sort.map do |id|
              relative = "#{CONFIGS_PREFIX}#{id}.yml"
              absolute = File.join(staging, relative)
              FileUtils.mkdir_p(File.dirname(absolute))
              File.write(absolute, feeds.fetch(id))
              relative
            end
          end

          ##
          # @param existing_path [String]
          # @return [Hash{String => String}]
          def existing_feed_contents(existing_path)
            return {} unless Store.bundle_present_at?(existing_path)

            manifest = Html2rss::Registry::Verifier.load_manifest(existing_path)
            manifest.files.each_key.with_object({}) do |relative, memo|
              absolute = File.join(existing_path, relative)
              next unless File.file?(absolute)

              config = YAML.safe_load_file(absolute, symbolize_names: true)
              id = config.is_a?(Hash) ? config.dig(:registry, :id).to_s : ''
              next if id.empty?

              memo[id] = File.read(absolute)
            end
          end

          ##
          # @param staging [String]
          # @param relative_paths [Array<String>]
          # @return [void]
          def write_manifest!(staging, relative_paths)
            file_index = Html2rss::Registry::Manifest.file_index(staging, relative_paths)
            manifest = Html2rss::Registry::Manifest.build(
              file_index:,
              registry_id: REGISTRY_ID,
              version: Time.now.utc.strftime('%Y%m%d%H%M%S'),
              public_key_id: PUBLIC_KEY_ID
            )
            File.write(File.join(staging, Html2rss::Registry::Manifest::MANIFEST_FILE), manifest.to_json)
          end

          ##
          # Staging directory on the same filesystem as +target+ so +File.rename+ works.
          #
          # @param target [String]
          # @return [String]
          def sibling_staging_dir(target)
            stamp = Process.clock_gettime(Process::CLOCK_MONOTONIC_RAW, :nanosecond)
            File.join(File.dirname(target), ".local-staging-#{Process.pid}-#{stamp}")
          end
        end
      end
    end
  end
end
