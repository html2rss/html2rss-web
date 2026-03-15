# frozen_string_literal: true

require 'json'
require 'logger'
require 'time'

module Html2rss
  module Web
    ##
    # Structured observability event emitter for request-critical paths.
    module Observability
      SCHEMA_VERSION = '1.0'

      class << self
        # @param event_name [String]
        # @param outcome [String] expected values: success|failure.
        # @param details [Hash{Symbol=>Object}]
        # @param level [Symbol]
        # @return [void]
        def emit(event_name:, outcome:, details: {}, level: :info)
          logger.public_send(level, build_payload(event_name, outcome, details).to_json)
        rescue StandardError => error
          handle_emit_error(error, event_name, outcome)
        end

        private

        # @return [Logger]
        def logger
          Thread.current[:observability_logger] ||= Logger.new($stdout).tap do |log|
            log.formatter = proc do |severity, datetime, _progname, msg|
              "#{{
                timestamp: datetime.iso8601,
                level: severity,
                service: 'html2rss-web',
                **JSON.parse(msg, symbolize_names: true)
              }.to_json}\n"
            end
          end
        end

        # @param error [StandardError]
        # @param event_name [String]
        # @param outcome [String]
        # @return [void]
        def handle_emit_error(error, event_name, outcome)
          Kernel.warn("Observability emit error: #{error.message}")
          Kernel.warn("event_name=#{event_name} outcome=#{outcome}")
        end

        # @param event_name [String]
        # @param outcome [String]
        # @param details [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def build_payload(event_name, outcome, details)
          context = RequestContext.current_h
          base_payload(event_name, outcome, context).merge(details: details)
        end

        # @param event_name [String]
        # @param outcome [String]
        # @param context [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def base_payload(event_name, outcome, context)
          {
            event_name: event_name, schema_version: SCHEMA_VERSION, request_id: context[:request_id],
            route_group: context[:route_group], actor: context[:actor], outcome: outcome, **context_fields(context)
          }
        end

        # @param context [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def context_fields(context)
          context.slice(:path, :method, :strategy, :started_at)
        end
      end
    end
  end
end
