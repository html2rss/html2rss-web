# frozen_string_literal: true

require 'net/http'
require 'uri'

module Html2rss
  module Web
    module Registry
      ##
      # HTTPS fetcher with host allowlisting and bounded redirect following.
      module SyncFetcher
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

        RedirectPolicy = Data.define(:max_hops, :allowed_hosts) do
          ##
          # @return [RedirectPolicy]
          def self.default
            new(max_hops: DEFAULT_MAX_REDIRECTS, allowed_hosts: default_allowed_hosts)
          end

          ##
          # @return [Array<String>]
          def self.default_allowed_hosts
            DEFAULT_ALLOWED_HOSTS + SyncFetcher.extra_allowed_hosts
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
          ENV.fetch('REGISTRY_SYNC_ALLOWED_HOSTS', '')
             .split(',')
             .map(&:strip)
             .reject(&:empty?)
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
