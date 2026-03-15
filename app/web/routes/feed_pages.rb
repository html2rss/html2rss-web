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
            router.get String do |feed_name|
              next if feed_name.include?('.') && !feed_name.end_with?('.json', '.xml', '.rss')

              RequestTarget.mark!(router, RequestTarget::FEED)
              Feeds::Responder.call(request: router, target_kind: :static, identifier: feed_name)
            end

            router.root do
              index_renderer.call(router)
            end
          end
        end
      end
    end
  end
end
