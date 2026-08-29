# frozen_string_literal: true

module Html2rss
  module Web
    module Catalog
      ##
      # Domain catalog row for the public configs API (catalog_version 2).
      #
      # Always carries a {Feeds::LastResult}; wire encoding is {#to_h}.
      Entry = Data.define(
        :id,
        :path,
        :source,
        :directory,
        :channel,
        :parameters,
        :last_result
      ) do
        ##
        # Builds an entry from an embedded/local hash plus a last-result join.
        #
        # @param hash [Hash{Symbol => Object}]
        # @param last_result [Html2rss::Web::Feeds::LastResult]
        # @return [Html2rss::Web::Catalog::Entry]
        def self.from_hash(hash, last_result:)
          new(
            id: hash.fetch(:id),
            path: hash.fetch(:path),
            source: hash.fetch(:source),
            directory: hash.fetch(:directory),
            channel: hash.fetch(:channel),
            parameters: hash.fetch(:parameters),
            last_result:
          )
        end

        ##
        # Catalog wire shape (required +last_result+).
        #
        # @return [Hash{Symbol => Object}]
        def to_h
          {
            id:,
            path:,
            source:,
            directory:,
            channel:,
            parameters:,
            last_result: last_result.to_h
          }
        end
      end
    end
  end
end
