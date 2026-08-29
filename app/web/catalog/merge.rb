# frozen_string_literal: true

require 'html2rss/configs'

module Html2rss
  module Web
    ##
    # Merges embedded catalog entries with local feed configs for the public catalog API.
    module Catalog
      module Merge
        class << self
          ##
          # @return [Array<Html2rss::Web::Catalog::Entry>]
          def call
            (embedded_entries + local_entries).sort_by(&:id)
          end

          private

          # @return [Array<Html2rss::Web::Catalog::Entry>]
          def embedded_entries
            Html2rss::Configs::Catalog.entries.map { |entry| join_last_result(entry.to_h) }
          end

          # @return [Array<Html2rss::Web::Catalog::Entry>]
          def local_entries
            LocalConfig.feeds.filter_map do |feed_name, feed_config|
              hash = build_local_hash(feed_name, feed_config)
              next unless hash

              join_last_result(hash)
            end
          end

          # @param hash [Hash{Symbol => Object}]
          # @return [Html2rss::Web::Catalog::Entry]
          def join_last_result(hash)
            Entry.from_hash(hash, last_result: Feeds::LastResults[hash.fetch(:id)])
          end

          # @param feed_name [String, Symbol]
          # @param feed_config [Hash]
          # @return [Hash{Symbol => Object}, nil]
          def build_local_hash(feed_name, feed_config)
            directory = feed_config[:directory] || {}
            title = directory[:title]
            return nil if title.to_s.strip.empty?

            local_hash(feed_name.to_s, directory, title, feed_config)
          end

          # @param id [String]
          # @param directory [Hash]
          # @param title [String]
          # @param feed_config [Hash]
          # @return [Hash{Symbol => Object}]
          def local_hash(id, directory, title, feed_config)
            {
              id:,
              path: "/#{id}.rss",
              source: 'local',
              directory: local_directory(directory, title),
              channel: local_channel(feed_config[:channel] || {}, title),
              parameters: local_parameters(feed_config)
            }
          end

          # @param feed_config [Hash]
          # @return [Hash{Symbol => Object}]
          def local_parameters(feed_config)
            {
              schema: {},
              defaults: ParameterDefaults.extract(feed_config[:parameters])
            }
          end

          # @param directory [Hash]
          # @param title [String]
          # @return [Hash{Symbol => Object}]
          def local_directory(directory, title)
            {
              title: title.to_s,
              summary: directory[:summary],
              topics: Array(directory[:topics])
            }.compact
          end

          # @param channel [Hash]
          # @param title [String]
          # @return [Hash{Symbol => Object}]
          def local_channel(channel, title)
            {
              url: channel.fetch(:url),
              language: channel[:language],
              title: channel[:title] || title.to_s
            }.compact
          end
        end
      end
    end
  end
end
