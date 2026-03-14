# frozen_string_literal: true

require_relative '../request_target'

module Html2rss
  module Web
    module Routes
      ##
      # Mounts non-API routes (root page + legacy feed paths).
      #
      # This remains minimal by receiving handlers from the caller, keeping
      # routing concerns separate from rendering/business logic.
      module Static
        class << self
          # @param router [Roda::RodaRequest]
          # @param feed_handler [#call]
          # @param index_renderer [#call]
          # @return [void]
          def call(router, feed_handler:, index_renderer:)
            router.get String do |feed_name|
              next if feed_name.include?('.') && !feed_name.end_with?('.json', '.xml', '.rss')

              RequestTarget.mark!(router, RequestTarget::FEED)
              feed_handler.call(router, feed_name)
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
