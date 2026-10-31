# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Side effects for a classified error: rack.errors log, Observability event and Sentry capture.
    module ErrorReporter
      class << self
        # @param request [Rack::Request]
        # @param error [StandardError]
        # @param decision [ErrorClassifier::Decision]
        # @return [void]
        def report(request:, error:, decision:)
          emit_event(error, decision)
          log_internal(request, error)
          capture_unexpected(error, decision)
        end

        private

        # @param error [StandardError]
        # @param decision [ErrorClassifier::Decision]
        # @return [void]
        def emit_event(error, decision)
          details = { error_class: error.class.name, error_code: decision.code, error_message: error.message,
                      status: decision.status, **ErrorClassifier::Diagnostics.from_error(error).to_h }
          Observability.failure('request.error', details)
        end

        # @param request [Rack::Request]
        # @param error [StandardError]
        # @return [void]
        def log_internal(request, error)
          return if error.is_a?(HttpError)

          id = request.env['html2rss.request_context']&.request_id || request.get_header('HTTP_X_REQUEST_ID')
          request.env['rack.errors']&.puts(id ? "[request_id=#{id}] #{error.message}" : error.message)
        end

        # Captures unexpected non-HTTP internal faults in Sentry when enabled.
        #
        # @param error [StandardError]
        # @param decision [ErrorClassifier::Decision]
        # @return [void]
        def capture_unexpected(error, decision)
          return if error.is_a?(HttpError)
          return unless decision.code == ErrorClassifier::INTERNAL_SERVER_ERROR.code
          return unless RuntimeEnv.sentry_enabled?

          ::Sentry.capture_exception(error)
        rescue StandardError
          nil
        end
      end
    end
  end
end
