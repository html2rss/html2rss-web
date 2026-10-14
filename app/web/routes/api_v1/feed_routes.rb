# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      module ApiV1
        ##
        # Mounts feed-related API routes under `/api/v1/feeds`.
        module FeedRoutes
          STUDIO_POSTS = {
            'validate' => Api::V1::ValidateConfig,
            'preview' => Api::V1::PreviewFeed,
            'suggest_selectors' => Api::V1::SuggestSelectors
          }.freeze

          class << self
            # @param router [Roda::RodaRequest]
            # @return [void]
            def call(router)
              router.on 'feeds' do
                mount_studio_posts(router)
                mount_token_get(router)

                router.post { JSON.generate(Api::V1::CreateFeed.call(router)) }

                raise NotFoundError
              end
            end

            private

            # @param router [Roda::RodaRequest]
            # @return [void]
            def mount_studio_posts(router)
              STUDIO_POSTS.each do |path, handler|
                router.post(path) { JSON.generate(handler.call(router)) }
              end
            end

            # @param router [Roda::RodaRequest]
            # @return [void]
            def mount_token_get(router)
              router.get(String) do |token|
                router.env[RequestTarget::ENV_KEY] = RequestTarget::FEED
                Feeds::Responder.call(request: router, target_kind: :token, identifier: token)
              end
            end
          end
        end
      end
    end
  end
end
