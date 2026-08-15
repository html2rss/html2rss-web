# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Shared structured log emitter for Observability and SecurityLogger.
    module LogEvent
      class << self
        # @param payload [Hash{Symbol=>Object}]
        # @param level [Symbol]
        # @return [void]
        def emit(payload:, level: :info)
          logger.public_send(level, build_payload(payload).to_json)
        rescue StandardError => error
          warn_fallback(error, payload)
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

        # @param error [StandardError]
        # @param payload [Hash{Symbol=>Object}]
        # @return [void]
        def warn_fallback(error, payload)
          sanitized = LogSanitizer.sanitize_details(payload)
          Kernel.warn("Structured logging fallback: #{error.class}: #{error.message}")
          Kernel.warn("payload=#{sanitized}")
        end
      end
    end
  end
end
