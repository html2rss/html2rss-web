# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      module ApiV1
        ##
        # Mounts config-refine API routes under `/api/v1/refine`.
        module RefineRoutes
          HANDLERS = {
            'validate' => Api::V1::Refine::Validate,
            'preview' => Api::V1::Refine::Preview,
            'suggest_selectors' => Api::V1::Refine::Suggest
          }.freeze

          class << self
            # @param router [Roda::RodaRequest]
            # @return [void]
            def call(router)
              router.on 'refine' do
                HANDLERS.each do |path, handler|
                  router.post(path) { JSON.generate(handler.call(router)) }
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
