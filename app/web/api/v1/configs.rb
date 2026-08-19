# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Public config catalog endpoint for feed directory clients.
        module Configs
          CATALOG_VERSION = 1

          class << self
            ##
            # @param _router [Roda::RodaRequest]
            # @return [Hash{Symbol => Object}]
            def index(_router)
              started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              entries = Html2rss::Web::Catalog::Merge.call
              duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

              Observability.emit(
                event_name: 'catalog.build',
                outcome: 'success',
                details: { count: entries.size, duration_ms: }
              )

              Response.success(
                data: { configs: entries },
                meta: { total: entries.size, catalog_version: CATALOG_VERSION }
              )
            rescue Html2rss::Configs::Catalog::MissingDirectoryTitle => error
              Observability.emit(
                event_name: 'catalog.build',
                outcome: 'failure',
                level: :warn,
                details: { reason: error.message }
              )
              raise
            end
          end
        end
      end
    end
  end
end
