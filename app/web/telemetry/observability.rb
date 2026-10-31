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

        # Emits an +info+ +success+ event; trailing keyword arguments become +details+.
        #
        # @param event_name [String]
        # @param details [Hash{Symbol=>Object}]
        # @return [void]
        def success(event_name, details = {}) = emit(event_name:, outcome: 'success', details:, level: :info)

        # Emits an +error+ +failure+ event; trailing keyword arguments become +details+.
        #
        # @param event_name [String]
        # @param details [Hash{Symbol=>Object}]
        # @return [void]
        def failure(event_name, details = {}) = emit(event_name:, outcome: 'failure', details:, level: :error)
      end
    end
  end
end
