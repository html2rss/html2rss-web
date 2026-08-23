# frozen_string_literal: true

require 'json'

module Html2rss
  module Web
    module Registry
      ##
      # Resolves download URLs for official registry channels and GitHub release tags.
      module ChannelResolver
        OFFICIAL_GITHUB_RELEASES_API = 'https://api.github.com/repos/html2rss/html2rss-configs/releases/latest'
        OFFICIAL_GITHUB_TAG_RELEASES_API = 'https://api.github.com/repos/html2rss/html2rss-configs/releases/tags/%<tag>s'
        OFFICIAL_ASSET_NAME = 'registry-bundle.tar.gz'

        module_function

        ##
        # @param definition [Definition]
        # @return [String] download URL
        def resolve(definition)
          return definition.sync_url if definition.sync_url && !definition.sync_url.empty?

          if definition.sync_channel == Config::DEFAULT_OFFICIAL_SYNC_CHANNEL
            pin = definition.sync_policy.pin_version
            return Config::OFFICIAL_RELEASE_URL if pin.nil? || pin.empty?

            api_url = format(OFFICIAL_GITHUB_TAG_RELEASES_API, tag: pin)
            return resolve_github_asset(api_url, tag: pin)
          end

          raise Errors::SyncError, "Registry '#{definition.id}' has no sync URL"
        end

        ##
        # @param api_url [String]
        # @param tag [String, nil]
        # @return [String]
        def resolve_github_asset(api_url, tag: nil) # rubocop:disable Metrics/MethodLength
          body = HttpTransport.fetch!(api_url)
          release = JSON.parse(body, symbolize_names: true)
          asset = Array(release[:assets]).find { it[:name] == OFFICIAL_ASSET_NAME }
          url = asset&.dig(:browser_download_url)
          unless url
            raise Errors::SyncError,
                  "Official asset '#{OFFICIAL_ASSET_NAME}' not found#{" for #{tag}" if tag}"
          end

          url
        rescue JSON::ParserError => error
          raise Errors::SyncError, "Invalid GitHub release metadata: #{error.message}"
        end
      end
    end
  end
end
