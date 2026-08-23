# frozen_string_literal: true

require 'net/http'
require 'uri'

module Html2rss
  module Web
    module Registry
      ##
      # HTTPS client for fetching remote registry bundles.
      module HttpTransport
        DEFAULT_ALLOWED_HOSTS = %w[
          api.github.com
          github.com
          objects.githubusercontent.com
          release-assets.githubusercontent.com
        ].freeze
        OPEN_TIMEOUT_SECONDS = 10
        READ_TIMEOUT_SECONDS = 60
        MAX_RESPONSE_BYTES = 52_428_800
        DEFAULT_MAX_REDIRECTS = 5

        module_function

        ##
        # @param url [String]
        # @param max_redirects [Integer]
        # @param allowed_hosts [Array<String>]
        # @return [String] response body
        def fetch!(url, max_redirects: DEFAULT_MAX_REDIRECTS, allowed_hosts: default_allowed_hosts) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          uri = parse_https_uri!(url)
          hops = 0

          loop do
            ensure_allowed_host!(uri.host, allowed_hosts)
            response = perform_request(uri)

            case response
            in Net::HTTPRedirection
              hops += 1
              raise Errors::SyncError, 'Registry sync exceeded redirect limit' if hops > max_redirects

              location = response['location']
              raise Errors::SyncError, 'Registry sync redirect missing Location header' if location.to_s.empty?

              uri = parse_https_uri!(URI.join(uri, location).to_s)
            in Net::HTTPSuccess
              return read_body(response)
            else
              raise Errors::SyncError, "Registry sync fetch failed with HTTP #{response.code}"
            end
          end
        end

        ##
        # @return [Array<String>]
        def default_allowed_hosts
          extra = ENV.fetch('REGISTRY_SYNC_ALLOWED_HOSTS', '').split(',').map(&:strip).reject(&:empty?)
          DEFAULT_ALLOWED_HOSTS + extra
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
        def perform_request(uri) # rubocop:disable Metrics/MethodLength
          Net::HTTP.start(
            uri.host,
            uri.port,
            use_ssl: true,
            open_timeout: OPEN_TIMEOUT_SECONDS,
            read_timeout: READ_TIMEOUT_SECONDS
          ) do |http|
            request = Net::HTTP::Get.new(uri)
            request['Accept'] = 'application/octet-stream'
            request['User-Agent'] = 'html2rss-web/registry-sync'
            http.request(request)
          end
        end

        ##
        # @param response [Net::HTTPResponse]
        # @return [String]
        def read_body(response)
          body = response.body.to_s
          if body.bytesize > MAX_RESPONSE_BYTES
            raise Errors::SyncError,
                  "Response exceeds max bytes (#{MAX_RESPONSE_BYTES})"
          end

          body
        end
      end
    end
  end
end
