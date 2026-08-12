# frozen_string_literal: true

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
              Feeds::ChannelTitle.for(url)
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
          CreateParams = Data.define(:url, :name)

          ##
          # Feed metadata contract used between creation services and API responses.
          Metadata = Data.define(:id, :name, :url, :username, :feed_token, :public_url, :json_public_url)
        end
      end
    end
  end
end
