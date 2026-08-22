# frozen_string_literal: true

module Html2rss
  module Web
    module Registry
      ##
      # Catalog wire row for local feeds.yml entries.
      LocalCatalogRow = Data.define(
        :id,
        :path,
        :directory,
        :channel,
        :parameters,
        :source
      )
    end
  end
end
