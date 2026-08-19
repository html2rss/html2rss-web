# frozen_string_literal: true

require 'html2rss/configs'

module Html2rss
  module Web
    ##
    # Merges embedded catalog entries with local feed configs for the public catalog API.
    module Catalog
      module Merge
        STARTER_FEED_IDS = %w[
          microsoft.com/azure-products
          phys.org/weekly
          softwareleadweekly.com/issues
        ].freeze

        module_function

        ##
        # @return [Array<Hash{Symbol => Object}>]
        def call
          embedded = Html2rss::Configs::Catalog.entries.map(&:to_h)
          local = local_entries
          (embedded + local).sort_by { |entry| entry.fetch(:id) }
        end

        ##
        # @return [Array<Hash{Symbol => Object}>]
        def starter_entries
          entries = call
          selected = STARTER_FEED_IDS.filter_map { |id| entries.find { |entry| entry.fetch(:id) == id } }
          selected.empty? ? entries.first(3) : selected
        end

        ##
        # @return [Array<Hash{Symbol => Object}>]
        def local_entries
          LocalConfig.feeds.filter_map do |feed_name, feed_config|
            build_local_entry(feed_name, feed_config)
          end
        end

        ##
        # @param feed_name [String, Symbol]
        # @param feed_config [Hash]
        # @return [Hash{Symbol => Object}, nil]
        def build_local_entry(feed_name, feed_config)
          directory = feed_config[:directory] || {}
          title = directory[:title]
          return nil if title.to_s.strip.empty?

          id = feed_name.to_s
          channel = feed_config[:channel] || {}

          {
            id:,
            path: "/#{id}.rss",
            source: 'local',
            directory: {
              title: title.to_s,
              summary: directory[:summary],
              topics: Array(directory[:topics])
            }.compact,
            channel: {
              url: channel.fetch(:url),
              language: channel[:language],
              title: channel[:title] || title.to_s
            }.compact,
            parameters: { schema: {}, defaults: {} }
          }
        end
      end
    end
  end
end
