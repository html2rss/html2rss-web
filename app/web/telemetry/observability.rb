# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Product telemetry channel (dotted event_name + outcome). Request correlation
    # comes from {LogEvent} via {RequestContext}; IP/UA stay on {SecurityLogger}.
    module Observability
      SCHEMA_VERSION = '1.0'

      class << self
        # @param event_name [String]
        # @param outcome [String] expected values: success|failure.
        # @param details [Hash{Symbol=>Object}]
        # @param level [Symbol]
        # @return [void]
        def emit(event_name:, outcome:, details: {}, level: :info)
          LogEvent.emit(
            level:,
            payload: {
              event_name:,
              schema_version: SCHEMA_VERSION,
              outcome:,
              details:
            }
          )
        end
      end
    end
  end
end
