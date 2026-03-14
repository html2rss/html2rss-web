# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Immutable feed response payload plus cache metadata.
    FeedRenderResult = Data.define(:body, :ttl_seconds)
  end
end
