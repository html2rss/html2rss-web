# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Shared structured log emitter for request-scoped application events.
    module LogEvent
      class << self
        # @param payload [Hash{Symbol=>Object}]
        # @param level [Symbol]
        # @return [void]
        def emit(payload:, level: :info)
          logger.public_send(level, build_payload(payload).to_json)
        end

        private

        # @return [Logger]
        def logger
          AppLogger.logger
        end

        # @param payload [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def build_payload(payload)
          RequestContext.current_h.merge(LogSanitizer.sanitize_details(payload))
        end
      end
    end
  end
end
