# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'json'
require 'stringio'
require 'uri'

module Html2rss
  module Web
    module Registry
      ##
      # Fetches, verifies, and stores signed registry bundles.
      module Sync # rubocop:disable Metrics/ModuleLength
        OFFICIAL_RELEASE_URL = Config::OFFICIAL_RELEASE_URL
        OFFICIAL_GITHUB_RELEASES_API =
          'https://api.github.com/repos/html2rss/html2rss-configs/releases/latest'
        OFFICIAL_ASSET_NAME = 'registry-bundle.tar.gz'

        DEFAULT_ALLOWED_HOSTS = %w[
          api.github.com
          github.com
          objects.githubusercontent.com
        ].freeze
        FETCH_OPEN_TIMEOUT_SECONDS = 10
        FETCH_READ_TIMEOUT_SECONDS = 60
        MAX_RESPONSE_BYTES = Html2rss::Registry::Archive::MAX_TARBALL_BYTES
        BACKGROUND_JITTER_FRACTION = 0.1

        SyncStatus = Data.define(:registry_id, :mode, :version, :updated_at, :sync_url, :last_error)

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

            resolve_download_url(entry)
          end

          ##
          # Runs synchronization for a registry id.
          #
          # @param registry_id [String, Symbol]
          # @param dry_run [Boolean] when true, verify without swapping the active bundle
          # @return [SyncStatus]
          def run(registry_id:, dry_run: false) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
            entry = Config.entry(registry_id)
            if entry.mode == :path
              raise Errors::SyncError, "Registry '#{registry_id}' uses path mode; sync is not applicable"
            end

            staging_root = nil
            download_url = resolve_download_url(entry)
            staging_root, staged_dir = fetch_and_verify!(entry, download_url)
            unless dry_run
              Store.swap!(registry_id, staged_dir)
              Index.reload!
              record_success!(registry_id)
            end
            sync_status_for(Index.current.status.find { |row| row.id == registry_id.to_s })
          rescue StandardError => error
            record_failure!(registry_id, error) unless dry_run
            raise
          ensure
            FileUtils.rm_rf(staging_root) if staging_root
          end

          ##
          # @param registry_id [String, Symbol, nil]
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

          ##
          # @param entry [Entry]
          # @return [String]
          def resolve_download_url(entry)
            return entry.sync_url if entry.sync_url && !entry.sync_url.empty?
            return resolve_official_download_url if entry.sync_channel == Config::DEFAULT_OFFICIAL_SYNC_CHANNEL

            raise Errors::SyncError, "Registry '#{entry.id}' has no sync URL"
          end

          ##
          # @return [String]
          def resolve_official_download_url
            response_body = Fetcher.fetch!(OFFICIAL_GITHUB_RELEASES_API)
            release = JSON.parse(response_body, symbolize_names: true)
            asset = Array(release[:assets]).find { |row| row[:name] == OFFICIAL_ASSET_NAME }
            url = asset&.dig(:browser_download_url)
            raise Errors::SyncError, "Official release asset '#{OFFICIAL_ASSET_NAME}' not found" unless url

            url
          rescue JSON::ParserError => error
            raise Errors::SyncError, "Invalid GitHub release metadata: #{error.message}"
          end

          ##
          # @param entry [Entry]
          # @param download_url [String]
          # @return [Array(String, String)] staging root and verified bundle directory
          def fetch_and_verify!(entry, download_url) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
            tarball = Fetcher.fetch!(download_url)
            staging_root = Dir.mktmpdir('registry-sync-')
            staged_dir = File.join(staging_root, 'bundle')
            FileUtils.mkdir_p(staged_dir)

            StringIO.open(tarball) do |io|
              Html2rss::Registry::Archive.extract!(io, into: staged_dir)
            end

            Html2rss::Registry::Verifier.verify!(
              staged_dir,
              trust: :signed,
              public_keys: entry.public_keys
            )
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
          # @param registry_id [String]
          # @return [void]
          def record_success!(registry_id)
            Store.write_sync_state!(registry_id, last_error: nil)
            row = Index.current.status.find { |entry| entry.id == registry_id.to_s }
            Observability.emit(
              event_name: 'registry.sync',
              outcome: 'success',
              details: { registry_id:, version: row&.version }
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
          def sync_status_for(row)
            entry = Config.entry(row.id)
            state = Store.sync_state(row.id)
            SyncStatus.new(
              registry_id: row.id,
              mode: row.sync_mode,
              version: row.version,
              updated_at: row.updated_at,
              sync_url: entry.mode == :sync ? resolve_download_url(entry) : nil,
              last_error: state['last_error']
            )
          end
        end # rubocop:enable Metrics/ClassLength

        ##
        # HTTPS fetcher with host allowlisting and redirect rejection.
        module Fetcher
          module_function

          ##
          # @param url [String]
          # @return [String] response body
          def fetch!(url)
            uri = parse_https_uri!(url)
            ensure_allowed_host!(uri.host)
            perform_request!(uri)
          end

          ##
          # @param url [String]
          # @return [URI::HTTPS]
          def parse_https_uri!(url)
            uri = URI(url)
            unless uri.is_a?(URI::HTTPS)
              raise Errors::SyncError, "Registry sync requires HTTPS URLs (got #{uri.scheme.inspect})"
            end

            uri
          end

          ##
          # @param host [String]
          # @return [void]
          def ensure_allowed_host!(host)
            allowed = DEFAULT_ALLOWED_HOSTS + extra_allowed_hosts
            return if allowed.include?(host)

            raise Errors::SyncError, "Registry sync host not allowed: #{host}"
          end

          ##
          # @return [Array<String>]
          def extra_allowed_hosts
            ENV.fetch('REGISTRY_SYNC_ALLOWED_HOSTS', '')
               .split(',')
               .map(&:strip)
               .reject(&:empty?)
          end

          ##
          # @param uri [URI::HTTPS]
          # @return [String]
          def perform_request!(uri) # rubocop:disable Metrics/MethodLength
            response = nil
            Net::HTTP.start(
              uri.host,
              uri.port,
              use_ssl: true,
              open_timeout: FETCH_OPEN_TIMEOUT_SECONDS,
              read_timeout: FETCH_READ_TIMEOUT_SECONDS
            ) do |http|
              request = Net::HTTP::Get.new(uri)
              request['Accept'] = 'application/octet-stream'
              request['User-Agent'] = 'html2rss-web/registry-sync'
              response = http.request(request)
            end

            reject_redirect!(response)
            reject_error_status!(response)
            read_body!(response)
          end

          ##
          # @param response [Net::HTTPResponse]
          # @return [void]
          def reject_redirect!(response)
            return unless response.is_a?(Net::HTTPRedirection)

            raise Errors::SyncError, 'Registry sync rejects HTTP redirects'
          end

          ##
          # @param response [Net::HTTPResponse]
          # @return [void]
          def reject_error_status!(response)
            return if response.is_a?(Net::HTTPSuccess)

            raise Errors::SyncError, "Registry sync fetch failed with HTTP #{response.code}"
          end

          ##
          # @param response [Net::HTTPResponse]
          # @return [String]
          def read_body!(response)
            body = response.body.to_s
            if body.bytesize > MAX_RESPONSE_BYTES
              raise Errors::SyncError, "Registry sync response exceeds max bytes (#{MAX_RESPONSE_BYTES})"
            end

            body
          end
        end
      end # rubocop:enable Metrics/ModuleLength
    end
  end
end
