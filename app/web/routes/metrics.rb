# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      ##
      # Serves Prometheus text at +GET /metrics+.
      module Metrics
        class << self
          # Mounts the scrape route. Unmatched requests return nil so later routes run.
          #
          # @param router [Roda::RodaRequest]
          # @return [String, nil]
          def call(router)
            router.get 'metrics' do
              authorize!(router)
              router.response['Content-Type'] = Telemetry::Metrics::CONTENT_TYPE
              Telemetry::Metrics.scrape
            end
          end

          private

          # @param router [Roda::RodaRequest]
          # @return [void]
          def authorize!(router)
            return if Api::V1::Health.authorized?(router)

            raise UnauthorizedError, 'Metrics authentication required'
          end
        end
      end
    end
  end
end
