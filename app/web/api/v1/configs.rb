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
              entries, duration_ms = build_entries
              emit_success(entries.size, duration_ms)
              success_payload(entries)
            rescue Html2rss::Configs::Catalog::MissingDirectoryTitle => error
              emit_failure(error)
              raise
            end

            private

            def build_entries
              started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              entries = Html2rss::Web::Catalog::Merge.call
              duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
              [entries, duration_ms]
            end

            def emit_success(count, duration_ms)
              Observability.emit(
                event_name: 'catalog.build',
                outcome: 'success',
                details: { count:, duration_ms: }
              )
            end

            def emit_failure(error)
              Observability.emit(
                event_name: 'catalog.build',
                outcome: 'failure',
                level: :warn,
                details: { reason: error.message }
              )
            end

            def success_payload(entries)
              Response.success(
                data: { configs: entries },
                meta: { total: entries.size, catalog_version: CATALOG_VERSION }
              )
            end
          end
        end
      end
    end
  end
end
