# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Normalized feed payload consumed by renderers and HTTP responders.
      Payload = Data.define(:feed, :site_title, :url, :strategy)
    end
  end
end
