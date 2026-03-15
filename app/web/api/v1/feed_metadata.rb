# frozen_string_literal: true

require 'html2rss/url'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Immutable contracts for feed creation and API serialization.
        module FeedMetadata
          class << self
            # @param url [String]
            # @return [String, nil]
            def site_title_for(url)
              Html2rss::Url.for_channel(url).channel_titleized
            rescue StandardError
              nil
            end

            # @param attributes [Hash{Symbol=>Object}]
            # @return [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            def build(attributes)
              Metadata.new(**metadata_attributes(attributes))
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

            # @param username [String]
            # @param url [String]
            # @param token [String]
            # @return [String]
            def stable_id(username, url, token)
              Digest::SHA256.hexdigest("#{username}:#{url}:#{token}")[0..15]
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

          ##
          # Feed create parameters contract.
          CreateParams = Data.define(:url, :name, :strategy) do
            # @return [Hash{Symbol=>Object}]
            def to_h
              { url: url, name: name, strategy: strategy }
            end
          end

          ##
          # Feed metadata contract used between creation services and API responses.
          Metadata = Data.define(:id, :name, :url, :username, :strategy, :feed_token, :public_url, :json_public_url) do
            # @return [Hash{Symbol=>Object}]
            def to_h
              {
                id: id,
                name: name,
                url: url,
                username: username,
                strategy: strategy,
                feed_token: feed_token,
                public_url: public_url,
                json_public_url: json_public_url
              }
            end
          end
        end
      end
    end
  end
end
