# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      ##
      # Mounts the root page and legacy feed paths.
      module FeedPages
        class << self
          # @param router [Roda::RodaRequest]
          # @param index_renderer [#call]
          # @return [void]
          def call(router, index_renderer:)
            router.root do
              index_renderer.call(router)
            end

            router.get do
              feed_name = requested_feed_name(router)
              next if feed_name.empty?
              next if feed_name.include?('.') && !feed_name.end_with?('.json', '.xml', '.rss')

              RequestTarget.mark!(router, RequestTarget::FEED)
              Feeds::Responder.call(request: router, target_kind: :static, identifier: feed_name)
            end
          end

          private

          # @param router [Roda::RodaRequest]
          # @return [String]
          def requested_feed_name(router)
            router.path_info.to_s.delete_prefix('/')
          end
        end
      end
    end
  end
end
