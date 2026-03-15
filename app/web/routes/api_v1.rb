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

              mount_openapi_spec(router)
              mount_health(router)
              mount_strategies(router)
              mount_feeds(router)
              mount_root(router)
            end
          end

          private

          # @param router [Roda::RodaRequest]
          # @return [void]
          def mount_openapi_spec(router)
            router.on 'openapi.yaml' do
              router.get do
                router.response['Content-Type'] = 'application/yaml'
                openapi_spec_contents
              end
            end
          end

          # @param router [Roda::RodaRequest]
          # @return [void]
          def mount_health(router)
            router.on 'health' do
              mount_health_subroutes(router)

              router.get do
                render_json(Api::V1::Health.show(router))
              end
            end
          end

          # @param router [Roda::RodaRequest]
          # @return [void]
          def mount_health_subroutes(router)
            mount_readiness_health(router)
            mount_liveness_health(router)
          end

          # @param router [Roda::RodaRequest]
          # @return [void]
          def mount_readiness_health(router)
            router.on 'ready' do
              router.get do
                render_json(Api::V1::Health.ready(router))
              end
            end
          end

          # @param router [Roda::RodaRequest]
          # @return [void]
          def mount_liveness_health(router)
            router.on 'live' do
              router.get do
                render_json(Api::V1::Health.live(router))
              end
            end
          end

          # @param router [Roda::RodaRequest]
          # @return [void]
          def mount_strategies(router)
            router.on 'strategies' do
              router.get do
                render_json(Api::V1::Strategies.index(router))
              end
            end
          end

          # @param router [Roda::RodaRequest]
          # @return [void]
          def mount_feeds(router)
            router.on 'feeds' do
              router.get String do |token|
                RequestTarget.mark!(router, RequestTarget::FEED)
                Feeds::Responder.call(request: router, target_kind: :token, identifier: token)
              end

              router.post do
                render_json(Api::V1::CreateFeed.call(router))
              end
            end
          end

          # @param router [Roda::RodaRequest]
          # @return [void]
          def mount_root(router)
            router.get do
              render_json(Api::V1::Response.success(data: api_root_payload(router)))
            end
          end

          # @param router [Roda::RodaRequest]
          # @return [Hash{Symbol=>Object}] API capability payload.
          # @option return [Hash] :api API metadata block.
          # @option return [String] :name API display name.
          # @option return [String] :description human-readable API description.
          # @option return [String] :openapi_url absolute OpenAPI spec URL.
          # @option return [Hash] :demo public demo metadata block.
          def api_root_payload(router)
            Api::V1::RootMetadata.build(router)
          end

          # @param payload [Hash{Symbol=>Object}]
          # @return [String] serialized JSON payload.
          def render_json(payload)
            JSON.generate(payload)
          end

          # @return [String] absolute file path for bundled OpenAPI spec.
          def openapi_spec_path
            File.expand_path('../../docs/api/v1/openapi.yaml', __dir__)
          end

          # @return [String] YAML OpenAPI content, with minimal fallback.
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
