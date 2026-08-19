# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      module ApiV1
        ##
        # Mounts the public config catalog endpoint with route-scoped CORS.
        module ConfigsRoutes
          CORS_HEADERS = {
            'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Methods' => 'GET, OPTIONS',
            'Access-Control-Allow-Headers' => 'Accept, Content-Type'
          }.freeze

          class << self
            ##
            # @param router [Roda::RodaRequest]
            # @return [void]
            def call(router)
              router.on 'configs' do
                apply_cors!(router)

                router.options do
                  router.response.status = 204
                  ''
                end

                router.get do
                  unless Flags.config_catalog_enabled?
                    router.response.status = 404
                    next JSON.generate(error: 'catalog_disabled')
                  end

                  JSON.generate(Api::V1::Configs.index(router))
                end
              end
            end

            private

            # @param router [Roda::RodaRequest]
            # @return [void]
            def apply_cors!(router)
              CORS_HEADERS.each { |header, value| router.response[header] = value }
            end
          end
        end
      end
    end
  end
end
