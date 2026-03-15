# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      ##
      # Wires all API v1 routes in one place.
      #
      # Keeping route assembly centralized keeps HTTP entry behavior easy to
      # reason about and avoids duplicated content-type/render logic.
      module ApiV1
        class << self
          # Mounts `/api/v1` routes on the provided router.
          #
          # @param router [Roda::RodaRequest]
          # @return [void]
          def call(router)
            router.on 'api', 'v1' do
              RequestTarget.mark!(router, RequestTarget::API)
              router.response['Content-Type'] = 'application/json'

              HealthRoutes.call(router)
              FeedRoutes.call(router)
              MetadataRoutes.call(router)
            end
          end
        end
      end
    end
  end
end
