# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Builds the public metadata payload for the API root endpoint.
        module RootMetadata
          class << self
            # @param router [Roda::RodaRequest]
            # @return [Hash{Symbol=>Object}]
            def build(router)
              {
                api: {
                  name: 'html2rss-web API',
                  description: 'RESTful API for converting websites to RSS feeds',
                  openapi_url: "#{router.base_url}/openapi.yaml"
                },
                instance: instance_payload(router)
              }
            end

            private

            # @param router [Roda::RodaRequest]
            # @return [Hash{Symbol=>Object}]
            def instance_payload(router)
              {
                feed_creation: {
                  enabled: Flags.auto_source_enabled?,
                  access_token_required: Flags.auto_source_enabled?
                },
                catalog: {
                  enabled: Flags.config_catalog_enabled?,
                  url: "#{router.base_url}/api/v1/configs"
                }
              }
            end
          end
        end
      end
    end
  end
end
