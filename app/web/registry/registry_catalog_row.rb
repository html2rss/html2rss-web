# frozen_string_literal: true

module Html2rss
  module Web
    module Registry
      ##
      # Catalog wire row for registry-sourced feed configs.
      RegistryCatalogRow = Data.define(
        :id,
        :path,
        :directory,
        :channel,
        :parameters,
        :source,
        :registry
      ) do
        ##
        # @param entry [Html2rss::Registry::CatalogEntry]
        # @param registry_id [String]
        # @return [RegistryCatalogRow]
        def self.from_entry(entry, registry_id)
          new(
            id: entry.id,
            path: entry.path,
            directory: entry.directory,
            channel: entry.channel,
            parameters: entry.parameters,
            source: 'registry',
            registry: registry_id
          )
        end
      end
    end
  end
end
