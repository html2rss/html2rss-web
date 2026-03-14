# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Normalized source inputs for shared feed generation.
      ResolvedSource = Data.define(:source_kind, :cache_identity, :generator_input, :ttl_seconds)
    end
  end
end
