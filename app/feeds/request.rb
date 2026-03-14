# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Request-edge contract for feed rendering.
      Request = Data.define(:target_kind, :representation, :feed_name, :token, :params)
    end
  end
end
