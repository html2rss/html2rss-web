# frozen_string_literal: true

require 'net/http'
require 'optparse'
require 'uri'

module Html2rss
  module Web
    ##
    # Unified command-line interface for operator workflows and container management.
    module CLI # rubocop:disable Metrics/ModuleLength
      STATUS_HEADERS = %w[registry mode version staged_version updated_at sync_url last_error].freeze

      module_function

      ##
      # Dispatches command-line arguments to the appropriate handler.
      #
      # @param argv [Array<String>] command-line arguments
      # @param out [IO] standard output stream
      # @param err [IO] standard error stream
      # @return [Integer] process exit code (0 for success, 1 for failure)
      def run(argv = ARGV, out: $stdout, err: $stderr) # rubocop:disable Metrics/MethodLength
        case argv.first
        when 'registry' then run_registry(argv[1..] || [], out:, err:)
        when 'healthcheck' then run_healthcheck(out:, err:)
        when 'version', '-v', '--version' then run_version(out:)
        when '-h', '--help', 'help', nil
          print_root_help(out:)
          0
        else
          err.puts "Unknown command: #{argv.first.inspect}. Run with --help for usage."
          1
        end
      end

      ##
      # @param args [Array<String>]
      # @param out [IO]
      # @param err [IO]
      # @return [Integer]
      def run_registry(args, out:, err:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
        case args.first
        when 'status' then registry_status(args[1..] || [], out:)
        when 'sync' then registry_sync(args[1..] || [])
        when 'promote' then registry_promote(args[1..] || [])
        when 'verify' then registry_verify(args[1..] || [], out:, err:)
        when '-h', '--help', 'help', nil
          print_registry_help(out:)
          0
        else
          err.puts "Unknown registry command: #{args.first.inspect}. Run with --help for usage."
          1
        end
      end

      ##
      # @param args [Array<String>]
      # @param out [IO]
      # @return [Integer]
      def registry_status(args, out:)
        options = { registry_id: nil }
        OptionParser.new do |opts|
          opts.banner = 'Usage: html2rss-web registry status [options]'
          opts.on('--registry ID', 'Inspect a single registry ID') { options[:registry_id] = it }
        end.parse!(args)

        print_status_table(options[:registry_id], out:)
        Registry::Sync.cli_exit_code
      end

      ##
      # @param args [Array<String>]
      # @return [Integer]
      def registry_sync(args)
        options = { registry_id: nil, dry_run: false }
        OptionParser.new do |opts|
          opts.banner = 'Usage: html2rss-web registry sync [options]'
          opts.on('--registry ID', 'Sync a single registry ID') { options[:registry_id] = it }
          opts.on('--dry-run', 'Fetch and verify without swapping active bundle') { options[:dry_run] = true }
        end.parse!(args)

        target_registry_ids(options[:registry_id]).each do |registry_id|
          Registry::Sync.run(registry_id:, dry_run: options[:dry_run])
        end
        Registry::Sync.cli_exit_code
      end

      ##
      # @param args [Array<String>]
      # @return [Integer]
      def registry_promote(args)
        options = { registry_id: nil }
        OptionParser.new do |opts|
          opts.banner = 'Usage: html2rss-web registry promote [options]'
          opts.on('--registry ID', 'Promote a single registry ID') { options[:registry_id] = it }
        end.parse!(args)

        target_registry_ids(options[:registry_id]).each do |registry_id|
          Registry::Sync.promote_staged!(registry_id:)
        end
        Registry::Sync.cli_exit_code
      end

      ##
      # @param args [Array<String>]
      # @param out [IO]
      # @param err [IO]
      # @return [Integer]
      def registry_verify(args, out:, err:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        options = { registry_id: 'official', dir: nil }
        OptionParser.new do |opts|
          opts.banner = 'Usage: html2rss-web registry verify [options]'
          opts.on('--registry ID', 'Registry ID from config (default: official)') { options[:registry_id] = it }
          opts.on('--dir PATH', 'Directory containing bundle to verify') { options[:dir] = it }
        end.parse!(args)

        registry_id = options[:registry_id]
        definition = Registry::Config.entry(registry_id)
        raise Registry::Errors::ConfigError, "Unknown registry '#{registry_id}'" unless definition

        dir = options[:dir] || Registry::Store.active_dir(registry_id) || Registry::Store.embedded_dir(registry_id)
        raise Registry::Errors::LoadError, "Bundle directory not found: #{dir}" unless dir && File.directory?(dir)

        trust = definition.mode == :path ? :integrity_only : :signed
        public_keys = definition.mode == :path ? {} : { definition.public_key_id => definition.public_key }.compact
        manifest = Html2rss::Registry::Verifier.verify!(dir, trust:, public_keys:)
        out.puts "Verified registry bundle '#{registry_id}' (#{manifest.version}) at #{dir}"
        0
      rescue StandardError => error
        err.puts "Registry verification failed: #{error.message}"
        1
      end

      ##
      # @param out [IO]
      # @param err [IO]
      # @return [Integer]
      def run_healthcheck(out:, err:) # rubocop:disable Metrics/MethodLength
        port = ENV.fetch('PORT', 4000)
        uri = URI.parse("http://127.0.0.1:#{port}/api/v1/health/live")
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPSuccess)
          out.puts 'OK'
          0
        else
          err.puts "Healthcheck failed: HTTP #{response.code}"
          1
        end
      rescue StandardError => error
        err.puts "Healthcheck failed: #{error.message}"
        1
      end

      ##
      # @param out [IO]
      # @return [Integer]
      def run_version(out:)
        out.puts "html2rss-web build=#{RuntimeEnv.build_tag} sha=#{RuntimeEnv.git_sha} ruby=#{RUBY_VERSION}"
        0
      end

      ##
      # @param out [IO]
      # @return [void]
      def print_root_help(out:)
        out.puts <<~HELP
          Usage: html2rss-web [command] [options]

          Commands:
            registry status [--registry ID]             Show status of configured registries
            registry sync [--registry ID] [--dry-run]   Fetch, verify, and sync registry bundles
            registry promote [--registry ID]            Promote verified staged bundle to active
            registry verify [--registry ID] [--dir DIR] Verify registry bundle signature and integrity
            healthcheck                                 Verify container process liveness
            version                                     Print version and runtime information
        HELP
      end

      ##
      # @param out [IO]
      # @return [void]
      def print_registry_help(out:)
        out.puts <<~HELP
          Usage: html2rss-web registry [subcommand] [options]

          Subcommands:
            status    Show registry sync status table
            sync      Fetch and verify remote registry bundle(s)
            promote   Promote staged verified bundle to active
            verify    Verify bundle signature and file integrity against pinned configuration
        HELP
      end

      ##
      # @param registry_id [String, nil]
      # @return [Array<String>]
      def target_registry_ids(registry_id)
        return Array(registry_id) if registry_id

        Registry::Config.precedence
      end

      ##
      # @param registry_id [String, nil]
      # @param out [IO]
      # @return [void]
      def print_status_table(registry_id, out:) # rubocop:disable Metrics/MethodLength
        rows = Registry::Sync.status(registry_id:)
        out.puts STATUS_HEADERS.join("\t")
        rows.each do |row|
          out.puts [
            row.id,
            row.mode,
            row.version || '-',
            row.staged_version || '-',
            format_time(row.updated_at),
            row.sync_url || '-',
            row.last_error || '-'
          ].join("\t")
        end
      end

      ##
      # @param value [Time, nil]
      # @return [String]
      def format_time(value) = value ? value.utc.iso8601 : '-'

      private_class_method :run_registry, :registry_status, :registry_sync, :registry_promote,
                           :registry_verify, :run_healthcheck, :run_version, :print_root_help,
                           :print_registry_help, :target_registry_ids, :print_status_table, :format_time
    end
  end
end
