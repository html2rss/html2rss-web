# frozen_string_literal: true

require 'concurrent/map'

module Html2rss
  module Web
    module Feeds
      ##
      # Process-local retention of directory-path {LastResult} values.
      #
      # Separate from {Cache}: outcomes outlive body TTL; cache hits do not
      # refresh +at+. Not a Redis/store twin — best-effort per worker.
      module LastResults
        # rubocop:disable-next ThreadSafety/ClassInstanceVariable
        def self.entries
          @entries ||= Concurrent::Map.new
        end
        private_class_method :entries

        class << self
          ##
          # Records a scrape outcome for +feed_name+.
          #
          # @param feed_name [String]
          # @param render_result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param clock [Proc] injectible clock returning a {Time}
          # @return [Html2rss::Web::Feeds::LastResult]
          def record(feed_name, render_result, clock: -> { Time.now.utc })
            last = LastResult.from_render_result(render_result, at: clock.call)
            entries[feed_name.to_s] = last
            last
          end

          ##
          # @param feed_name [String]
          # @return [Html2rss::Web::Feeds::LastResult]
          def [](feed_name)
            entries[feed_name.to_s] || LastResult.unknown
          end

          ##
          # @return [nil]
          def clear!
            entries.clear
            nil
          end
        end
      end
    end
  end
end
