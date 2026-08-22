# frozen_string_literal: true

module Html2rss
  module Web
    module Registry
      ##
      # Builds catalog wire rows for local feeds.yml entries.
      module LocalCatalog
        module_function

        ##
        # @return [Array<LocalCatalogRow>]
        def rows
          LocalConfig.feeds.filter_map do |feed_name, feed_config|
            build_row(feed_name, feed_config)
          end
        end

        ##
        # @param feed_name [String, Symbol]
        # @param feed_config [Hash{Symbol => Object}]
        # @return [LocalCatalogRow, nil]
        def build_row(feed_name, feed_config)
          directory = feed_config[:directory] || {}
          title = directory[:title]
          return nil if title.to_s.strip.empty?

          row_identity(feed_name, directory, title, feed_config[:channel] || {})
        end

        ##
        # @param feed_name [String, Symbol]
        # @param directory [Hash{Symbol => Object}]
        # @param title [String]
        # @param channel [Hash{Symbol => Object}]
        # @return [LocalCatalogRow]
        def row_identity(feed_name, directory, title, channel)
          id = feed_name.to_s
          LocalCatalogRow.new(
            id:,
            path: "/#{id}.rss",
            source: 'local',
            directory: directory_payload(directory, title),
            channel: channel_payload(channel, title),
            parameters: { schema: {}, defaults: {} }
          )
        end

        ##
        # @param directory [Hash{Symbol => Object}]
        # @param title [String]
        # @return [Hash{Symbol => Object}]
        def directory_payload(directory, title)
          {
            title: title.to_s,
            summary: directory[:summary],
            topics: Array(directory[:topics])
          }.compact
        end

        ##
        # @param channel [Hash{Symbol => Object}]
        # @param title [String]
        # @return [Hash{Symbol => Object}]
        def channel_payload(channel, title)
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
