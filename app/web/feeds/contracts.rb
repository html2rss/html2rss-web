# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Immutable contracts used across feed request resolution, generation, and rendering.
      module Contracts
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
end
