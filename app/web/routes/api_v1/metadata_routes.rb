# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      module ApiV1
        ##
        # Mounts OpenAPI, root metadata, and strategy listing endpoints.
        module MetadataRoutes
          class << self
            # @param router [Roda::RodaRequest]
            # @return [void]
            def call(router)
              mount_openapi_spec(router)
              mount_strategies(router)
              mount_root(router)
            end

            private

            # @param router [Roda::RodaRequest]
            # @return [void]
            def mount_openapi_spec(router)
              router.on 'openapi.yaml' do
                router.get do
                  router.redirect '/openapi.yaml', 301
                end
              end
            end

            # @param router [Roda::RodaRequest]
            # @return [void]
            def mount_strategies(router)
              router.on 'strategies' do
                router.get do
                  JSON.generate(Api::V1::Strategies.index(router))
                end
              end
            end

            # @param router [Roda::RodaRequest]
            # @return [void]
            def mount_root(router)
              router.root do
                router.get do
                  render_root_metadata(router)
                end
              end

              router.is do
                router.get do
                  render_root_metadata(router)
                end
              end
            end

            # @param router [Roda::RodaRequest]
            # @return [String]
            def render_root_metadata(router)
              JSON.generate(Api::V1::Response.success(data: Api::V1::RootMetadata.build(router)))
            end
          end
        end
      end
    end
  end
end
