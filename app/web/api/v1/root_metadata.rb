# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Builds the public metadata payload for the API root endpoint.
        module RootMetadata
          FEATURED_FEEDS = [
            {
              path: '/microsoft.com/azure-products.rss',
              title: 'Azure product updates',
              description: 'Follow Microsoft Azure product announcements from your own instance.'
            },
            {
              path: '/phys.org/weekly.rss',
              title: 'Top science news of the week',
              description: 'Try a high-signal feed with stable weekly headlines from the built-in config set.'
            },
            {
              path: '/softwareleadweekly.com/issues.rss',
              title: 'Software Lead Weekly issues',
              description: 'Follow a long-running newsletter archive from the embedded config catalog.'
            }
          ].freeze

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

            # @param _router [Roda::RodaRequest]
            # @return [Hash{Symbol=>Object}]
            def instance_payload(_router)
              {
                feed_creation: {
                  enabled: AutoSource.enabled?,
                  access_token_required: AutoSource.enabled?
                },
                featured_feeds: FEATURED_FEEDS
              }
            end
          end
        end
      end
    end
  end
end
