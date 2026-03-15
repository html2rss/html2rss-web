# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      module ApiV1
        ##
        # Mounts health and readiness endpoints under `/api/v1/health`.
        module HealthRoutes
          class << self
            # @param router [Roda::RodaRequest]
            # @return [void]
            def call(router)
              router.on 'health' do
                mount_readiness(router)
                mount_liveness(router)

                router.get do
                  JSON.generate(Api::V1::Health.show(router))
                end
              end
            end

            private

            # @param router [Roda::RodaRequest]
            # @return [void]
            def mount_readiness(router)
              router.on 'ready' do
                router.get do
                  JSON.generate(Api::V1::Health.ready(router))
                end
              end
            end

            # @param router [Roda::RodaRequest]
            # @return [void]
            def mount_liveness(router)
              router.on 'live' do
                router.get do
                  JSON.generate(Api::V1::Health.live(router))
                end
              end
            end
          end
        end
      end
    end
  end
end
