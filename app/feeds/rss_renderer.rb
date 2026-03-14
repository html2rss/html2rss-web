# frozen_string_literal: true

require_relative '../exceptions'
require_relative '../xml_builder'

module Html2rss
  module Web
    module Feeds
      ##
      # Renders RSS bodies from shared feed results.
      module RssRenderer
        class << self
          # @param result [Html2rss::Web::Feeds::Result]
          # @return [String]
          def call(result)
            case result.status
            when :ok
              result.payload.fetch(:feed).to_s
            when :empty
              empty_feed(result)
            else
              error_feed(result)
            end
          end

          private

          # @param result [Html2rss::Web::Feeds::Result]
          # @return [String]
          def empty_feed(result)
            XmlBuilder.build_empty_feed_warning(
              url: result.payload.fetch(:url),
              strategy: result.payload.fetch(:strategy),
              site_title: result.payload.fetch(:feed).channel.title
            )
          end

          # @param result [Html2rss::Web::Feeds::Result]
          # @return [String]
          def error_feed(result)
            XmlBuilder.build_error_feed(message: result.message || HttpError::DEFAULT_MESSAGE)
          end
        end
      end
    end
  end
end
