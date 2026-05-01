# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      module ApiV1
        ##
        # Mounts feed-related API routes under `/api/v1/feeds`.
        module FeedRoutes
          class << self
            # @param router [Roda::RodaRequest]
            # @return [void]
            def call(router)
              router.on 'feeds' do
                router.get String do |token|
                  router.env[RequestTarget::ENV_KEY] = RequestTarget::FEED
                  Feeds::Responder.call(request: router, target_kind: :token, identifier: token)
                end

                router.post do
                  JSON.generate(Api::V1::CreateFeed.call(router))
                end

                raise NotFoundError
              end
            end
          end
        end
      end
    end
  end
end
