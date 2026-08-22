# frozen_string_literal: true

require 'json'

module Html2rss
  module Web
    module Registry
      ##
      # Resolves registry sync download URLs from config entries and official release metadata.
      module SyncUrlResolver
        OFFICIAL_GITHUB_RELEASES_API =
          'https://api.github.com/repos/html2rss/html2rss-configs/releases/latest'
        OFFICIAL_GITHUB_TAG_RELEASES_API =
          'https://api.github.com/repos/html2rss/html2rss-configs/releases/tags/%<tag>s'
        OFFICIAL_ASSET_NAME = 'registry-bundle.tar.gz'

        module_function

        ##
        # @param entry [Entry]
        # @return [String]
        def resolve(entry)
          return entry.sync_url if entry.sync_url && !entry.sync_url.empty?

          pin_version = entry.sync_policy.pin_version
          if entry.sync_channel == Config::DEFAULT_OFFICIAL_SYNC_CHANNEL
            return resolve_official_tag_download_url(pin_version) if pin_version && !pin_version.empty?

            return resolve_official_download_url
          end

          raise Errors::SyncError, "Registry '#{entry.id}' has no sync URL"
        end

        ##
        # @param sync_channel [String, nil]
        # @return [String]
        def resolve_channel_url(sync_channel)
          channel = sync_channel && !sync_channel.empty? ? sync_channel : Config::DEFAULT_OFFICIAL_SYNC_CHANNEL
          return Config::OFFICIAL_RELEASE_URL if channel == Config::DEFAULT_OFFICIAL_SYNC_CHANNEL

          raise Errors::ConfigError, "Unknown sync channel '#{channel}'"
        end

        ##
        # @param tag [String]
        # @return [String]
        def resolve_official_tag_download_url(tag) # rubocop:disable Metrics/MethodLength
          api_url = format(OFFICIAL_GITHUB_TAG_RELEASES_API, tag:)
          response_body = SyncFetcher.fetch!(api_url)
          release = JSON.parse(response_body, symbolize_names: true)
          asset = Array(release[:assets]).find { |row| row[:name] == OFFICIAL_ASSET_NAME }
          url = asset&.dig(:browser_download_url)
          unless url
            raise Errors::SyncError,
                  "Official release asset '#{OFFICIAL_ASSET_NAME}' not found for tag '#{tag}'"
          end

          url
        rescue JSON::ParserError => error
          raise Errors::SyncError, "Invalid GitHub release metadata: #{error.message}"
        end

        ##
        # @return [String]
        def resolve_official_download_url
          response_body = SyncFetcher.fetch!(OFFICIAL_GITHUB_RELEASES_API)
          release = JSON.parse(response_body, symbolize_names: true)
          asset = Array(release[:assets]).find { |row| row[:name] == OFFICIAL_ASSET_NAME }
          url = asset&.dig(:browser_download_url)
          raise Errors::SyncError, "Official release asset '#{OFFICIAL_ASSET_NAME}' not found" unless url

          url
        rescue JSON::ParserError => error
          raise Errors::SyncError, "Invalid GitHub release metadata: #{error.message}"
        end
      end
    end
  end
end
