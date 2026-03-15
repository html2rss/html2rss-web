# frozen_string_literal: true

require 'digest'
require_relative '../api/v1/feed_metadata'

module Html2rss
  module Web
    ##
    # Builds stable identifiers and public URLs for feed contract objects.
    module FeedIdentity
      class << self
        # @param username [String]
        # @param url [String]
        # @param token [String]
        # @return [String]
        def stable_id(username, url, token)
          Digest::SHA256.hexdigest("#{username}:#{url}:#{token}")[0..15]
        end

        # @param attributes [Hash{Symbol=>Object}]
        # @return [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
        def metadata(attributes)
          Api::V1::FeedMetadata::Metadata.new(**metadata_attributes(attributes))
        end

        private

        # @param attributes [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def metadata_attributes(attributes)
          {
            id: stable_id(attributes[:username], attributes[:url], attributes[:identity_token]),
            name: attributes[:name],
            url: attributes[:url],
            username: attributes[:username],
            strategy: attributes[:strategy],
            feed_token: attributes[:feed_token],
            public_url: public_url(attributes[:feed_token]),
            json_public_url: json_public_url(attributes[:feed_token])
          }
        end

        # @param feed_token [String]
        # @return [String]
        def public_url(feed_token)
          "/api/v1/feeds/#{feed_token}"
        end

        # @param feed_token [String]
        # @return [String]
        def json_public_url(feed_token)
          "#{public_url(feed_token)}.json"
        end
      end
    end
  end
end
