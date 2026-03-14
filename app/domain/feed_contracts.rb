# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Immutable contracts used across feed creation, resolution, generation, and rendering.
    module FeedContracts
      ##
      # Feed create parameters contract.
      CreateParams = Data.define(:url, :name, :strategy) do
        # @return [Hash{Symbol=>Object}]
        def to_h
          { url: url, name: name, strategy: strategy }
        end
      end

      ##
      # Feed metadata contract used between feed services and API responses.
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

      ##
      # Request-edge contract for feed rendering.
      Request = Data.define(:target_kind, :representation, :feed_name, :token, :params)

      ##
      # Normalized source inputs for shared feed generation.
      ResolvedSource = Data.define(:source_kind, :cache_identity, :generator_input, :ttl_seconds)

      ##
      # Normalized feed payload consumed by renderers and HTTP responders.
      RenderPayload = Data.define(:feed, :site_title, :url, :strategy)

      ##
      # Shared feed-serving result wrapper.
      RenderResult = Data.define(:status, :payload, :message, :ttl_seconds, :cache_key, :error_message)
    end
  end
end
