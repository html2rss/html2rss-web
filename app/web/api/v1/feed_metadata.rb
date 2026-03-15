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
