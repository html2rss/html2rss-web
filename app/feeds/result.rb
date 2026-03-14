# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Shared feed-serving result wrapper.
      Result = Data.define(:status, :payload, :message, :ttl_seconds, :cache_key, :error_message)
    end
  end
end
