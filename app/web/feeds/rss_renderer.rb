# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Renders RSS bodies from shared feed results.
      module RssRenderer
        class << self
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [String]
          def call(result)
            case result.status
            when :ok
              result.payload.feed.to_s
            when :empty
              empty_feed(result)
            else
              error_feed(result)
            end
          end

          private

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [String]
          def empty_feed(result)
            XmlBuilder.build_empty_feed_warning(
              url: result.payload.url,
              strategy: result.payload.strategy,
              site_title: result.payload.site_title
            )
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [String]
          def error_feed(result)
            XmlBuilder.build_error_feed(message: result.message || Html2rss::Web::HttpError::DEFAULT_MESSAGE)
          end
        end
      end
    end
  end
end
