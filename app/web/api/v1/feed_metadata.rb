# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Immutable contracts for feed creation and API serialization.
        module FeedMetadata
          class << self
            # @param account [Hash{Symbol=>Object}]
            # @param name [String, nil]
            # @param url [String]
            # @param feed_token [String]
            # @return [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            def build(account:, name:, url:, feed_token:)
              username = account[:username]
              Metadata.new(
                id: stable_id(username, url, account[:token]),
                name: name,
                url: url,
                username: username,
                feed_token: feed_token,
                public_url: public_url(feed_token),
                json_public_url: json_public_url(feed_token)
              )
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
