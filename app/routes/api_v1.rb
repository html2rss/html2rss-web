# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      module ApiV1
        class << self
          def call(router)
            router.on 'api', 'v1' do
              router.response['Content-Type'] = 'application/json'

              mount_openapi_spec(router)
              mount_health(router)
              mount_strategies(router)
              mount_feeds(router)
              mount_root(router)
            end
          end

          private

          def mount_openapi_spec(router)
            router.on 'openapi.yaml' do
              router.get do
                router.response['Content-Type'] = 'application/yaml'
                openapi_spec_contents
              end
            end
          end

          def mount_health(router)
            router.on 'health' do
              mount_health_subroutes(router)

              router.get do
                render_json(Api::V1::Health.show(router))
              end
            end
          end

          def mount_health_subroutes(router)
            mount_readiness_health(router)
            mount_liveness_health(router)
          end

          def mount_readiness_health(router)
            router.on 'ready' do
              router.get do
                render_json(Api::V1::Health.ready(router))
              end
            end
          end

          def mount_liveness_health(router)
            router.on 'live' do
              router.get do
                render_json(Api::V1::Health.live(router))
              end
            end
          end

          def mount_strategies(router)
            router.on 'strategies' do
              router.get do
                render_json(Api::V1::Strategies.index(router))
              end
            end
          end

          def mount_feeds(router)
            router.on 'feeds' do
              router.get String do |token|
                render_feed_response(Api::V1::Feeds.show(router, token))
              end

              router.post do
                render_json(Api::V1::Feeds.create(router))
              end
            end
          end

          def mount_root(router)
            router.get do
              render_json(Api::V1::Response.success(data: api_root_payload(router)))
            end
          end

          def api_root_payload(router)
            {
              api: {
                name: 'html2rss-web API',
                description: 'RESTful API for converting websites to RSS feeds',
                openapi_url: "#{router.base_url}/api/v1/openapi.yaml"
              }
            }
          end

          def render_feed_response(result)
            result.is_a?(Hash) ? render_json(result) : result
          end

          def render_json(payload)
            JSON.generate(payload)
          end

          def openapi_spec_path
            File.expand_path('../../docs/api/v1/openapi.yaml', __dir__)
          end

          def openapi_spec_contents
            return File.read(openapi_spec_path) if File.exist?(openapi_spec_path)

            <<~YAML
              openapi: 3.0.3
              info:
                title: html2rss-web API
                version: 1.0.0
              paths: {}
            YAML
          end
        end
      end
    end
  end
end
