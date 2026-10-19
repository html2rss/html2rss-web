# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      ##
      # Mounts the root page and legacy feed paths.
      module FeedPages
        class << self
          # True for GET paths that the legacy static feed router serves.
          #
          # @param path [String]
          # @return [Boolean]
          def feed_path?(path) = feed_name_ok?(path.to_s.delete_prefix('/'))

          # @param router [Roda::RodaRequest]
          # @param index_renderer [#call]
          # @return [void]
          def call(router, index_renderer:)
            router.root { index_renderer.call(router) }
            router.get { serve_static_feed(router) }
          end

          private

          # @param name [String]
          # @return [Boolean]
          def feed_name_ok?(name)
            !name.empty? && !(name.include?('.') && !name.end_with?('.json', '.xml', '.rss'))
          end

          # @param router [Roda::RodaRequest]
          # @return [String, nil]
          def serve_static_feed(router)
            return unless feed_path?(router.path_info)

            router.env[RequestTarget::ENV_KEY] = RequestTarget::FEED
            Feeds::Responder.call(
              request: router, target_kind: :static, identifier: requested_feed_name(router)
            )
          end

          # @param router [Roda::RodaRequest]
          # @return [String]
          def requested_feed_name(router) = router.path_info.to_s.delete_prefix('/')
        end
      end
    end
  end
end
