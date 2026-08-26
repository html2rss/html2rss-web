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
                feed_creation: feed_creation_payload,
                catalog: catalog_payload(router),
                registries: registry_status_rows
              }
            end

            # @return [Hash{Symbol => Object}]
            def feed_creation_payload
              auto_source = Flags.auto_source_enabled?
              {
                enabled: auto_source,
                access_token_required: auto_source
              }
            end

            # @param router [Roda::RodaRequest]
            # @return [Hash{Symbol => Object}]
            def catalog_payload(router)
              {
                enabled: Flags.config_catalog_enabled?,
                url: "#{router.base_url}/api/v1/configs"
              }
            end

            # @return [Array<Hash{Symbol => Object}>]
            def registry_status_rows
              Registry::Index.current.status.map do |entry|
                {
                  id: entry.id,
                  version: entry.version,
                  updated_at: entry.updated_at&.utc&.iso8601,
                  sync_mode: entry.mode.to_s
                }
              end
            end
          end
        end
      end
    end
  end
end
