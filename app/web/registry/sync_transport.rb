# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module Html2rss
  module Web
    module Registry
      ##
      # HTTPS fetch, sync URL resolution, and manifest version gating for registry sync.
      module SyncTransport
        DEFAULT_ALLOWED_HOSTS = %w[
          api.github.com
          github.com
          objects.githubusercontent.com
          release-assets.githubusercontent.com
        ].freeze
        FETCH_OPEN_TIMEOUT_SECONDS = 10
        FETCH_READ_TIMEOUT_SECONDS = 60
        MAX_RESPONSE_BYTES = 52_428_800
        DEFAULT_MAX_REDIRECTS = 5

        OFFICIAL_GITHUB_RELEASES_API =
          'https://api.github.com/repos/html2rss/html2rss-configs/releases/latest'
        OFFICIAL_GITHUB_TAG_RELEASES_API =
          'https://api.github.com/repos/html2rss/html2rss-configs/releases/tags/%<tag>s'
        OFFICIAL_ASSET_NAME = 'registry-bundle.tar.gz'

        RedirectPolicy = Data.define(:max_hops, :allowed_hosts) do
          ##
          # @return [RedirectPolicy]
          def self.default
            new(max_hops: DEFAULT_MAX_REDIRECTS, allowed_hosts: default_allowed_hosts)
          end

          ##
          # @return [Array<String>]
          def self.default_allowed_hosts
            DEFAULT_ALLOWED_HOSTS + SyncTransport.extra_allowed_hosts
          end
        end

        module_function

        ##
        # @param url [String]
        # @param policy [RedirectPolicy]
        # @return [String] response body
        def fetch!(url, policy: RedirectPolicy.default)
          uri = parse_https_uri!(url)
          follow_redirects!(uri, policy)
        end

        ##
        # @param entry [Entry]
        # @return [String]
        def resolve(entry)
          return entry.sync_url unless entry.sync_url.to_s.empty?

          pin_version = entry.sync_policy.pin_version
          if entry.sync_channel == Config::DEFAULT_OFFICIAL_SYNC_CHANNEL
            unless pin_version.to_s.empty?
              api_url = format(OFFICIAL_GITHUB_TAG_RELEASES_API, tag: pin_version)
              return resolve_official_asset_url(api_url, tag: pin_version)
            end

            return resolve_official_asset_url(OFFICIAL_GITHUB_RELEASES_API)
          end

          raise Errors::SyncError, "Registry '#{entry.id}' has no sync URL"
        end

        ##
        # @param sync_channel [String, nil]
        # @return [String]
        def resolve_channel_url(sync_channel)
          channel = sync_channel.to_s.empty? ? Config::DEFAULT_OFFICIAL_SYNC_CHANNEL : sync_channel
          return Config::OFFICIAL_RELEASE_URL if channel == Config::DEFAULT_OFFICIAL_SYNC_CHANNEL

          raise Errors::ConfigError, "Unknown sync channel '#{channel}'"
        end

        ##
        # @param manifest_version [String]
        # @param max_version [String, nil]
        # @return [Boolean] true when manifest_version is newer than max_version
        def exceeds_max?(manifest_version, max_version)
          return false if max_version.nil? || max_version.empty?

          compare(normalize(manifest_version), normalize(max_version)).positive?
        end

        ##
        # @param uri [URI::HTTPS]
        # @param policy [RedirectPolicy]
        # @return [String]
        def follow_redirects!(uri, policy) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          hops = 0

          loop do
            ensure_allowed_host!(uri.host, policy.allowed_hosts)
            response = perform_request!(uri)

            case response
            in Net::HTTPRedirection
              hops += 1
              raise Errors::SyncError, 'Registry sync exceeded redirect limit' if hops > policy.max_hops

              location = response['location']
              raise Errors::SyncError, 'Registry sync redirect missing Location header' if location.to_s.empty?

              uri = parse_https_uri!(URI.join(uri, location).to_s)
              next
            else
              reject_error_status!(response)
              return read_body!(response)
            end
          end
        end

        ##
        # @return [Array<String>]
        def extra_allowed_hosts
          raw = ENV.fetch('REGISTRY_SYNC_ALLOWED_HOSTS', '')
          if defined?(@extra_allowed_hosts_raw) && @extra_allowed_hosts_raw == raw
            return @extra_allowed_hosts
          end

          @extra_allowed_hosts_raw = raw
          @extra_allowed_hosts = raw.split(',').map(&:strip).reject(&:empty?).freeze
        end

        ##
        # @param api_url [String]
        # @param tag [String, nil]
        # @return [String]
        def resolve_official_asset_url(api_url, tag: nil)
          response_body = fetch!(api_url)
          release = JSON.parse(response_body, symbolize_names: true)
          asset = Array(release[:assets]).find { it[:name] == OFFICIAL_ASSET_NAME }
          url = asset&.dig(:browser_download_url)
          unless url
            message = if tag
                        "Official release asset '#{OFFICIAL_ASSET_NAME}' not found for tag '#{tag}'"
                      else
                        "Official release asset '#{OFFICIAL_ASSET_NAME}' not found"
                      end
            raise Errors::SyncError, message
          end

          url
        rescue JSON::ParserError => error
          raise Errors::SyncError, "Invalid GitHub release metadata: #{error.message}"
        end

        ##
        # @param version [String]
        # @return [String]
        def normalize(version)
          version.to_s.delete_prefix('v')
        end

        ##
        # @param left [String]
        # @param right [String]
        # @return [Integer]
        def compare(left, right)
          Gem::Version.new(left) <=> Gem::Version.new(right)
        rescue ArgumentError
          left <=> right
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
        # @param allowed_hosts [Array<String>]
        # @return [void]
        def ensure_allowed_host!(host, allowed_hosts)
          return if allowed_hosts.include?(host)

          raise Errors::SyncError, "Registry sync host not allowed: #{host}"
        end

        ##
        # @param uri [URI::HTTPS]
        # @return [Net::HTTPResponse]
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
          response
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
    end
  end
end
