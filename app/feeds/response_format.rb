# frozen_string_literal: true

require_relative '../feed_response_format'

module Html2rss
  module Web
    module Feeds
      ##
      # Feed representation helpers scoped to the new feed pipeline.
      module ResponseFormat
        JSON_FEED = Html2rss::Web::FeedResponseFormat::JSON_FEED
        RSS = Html2rss::Web::FeedResponseFormat::RSS

        class << self
          # @param request [Rack::Request]
          # @return [Symbol]
          def for_request(request)
            Html2rss::Web::FeedResponseFormat.for_request(request)
          end

          # @param value [String]
          # @return [String]
          def strip_known_extension(value)
            Html2rss::Web::FeedResponseFormat.strip_known_extension(value)
          end

          # @param format [Symbol]
          # @return [String]
          def content_type(format)
            Html2rss::Web::FeedResponseFormat.content_type(format)
          end
        end
      end
    end
  end
end
