# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Process-local last-known scrape outcome for a directory-path feed.
      #
      # +state+ mirrors {Contracts::RenderResult#status} plus +:unknown+ when
      # the feed has never been scraped on defaults in this process.
      LastResult = Data.define(:state, :code, :at) do
        class << self
          ##
          # Cold / never-scraped projection.
          #
          # @return [Html2rss::Web::Feeds::LastResult]
          def unknown
            new(state: :unknown, code: nil, at: nil)
          end

          ##
          # Projects a real scrape {Contracts::RenderResult} into a last-result.
          #
          # @param render_result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param at [Time]
          # @return [Html2rss::Web::Feeds::LastResult]
          def from_render_result(render_result, at:)
            new(
              state: render_result.status,
              code: render_result.decision&.code,
              at:
            )
          end
        end

        ##
        # Wire shape for catalog entries.
        #
        # @return [Hash{Symbol => Object}]
        def to_h
          {
            state: state.to_s,
            code:,
            at: at&.utc&.iso8601
          }
        end
      end
    end
  end
end
