# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Centralized error rendering for API and XML endpoints.
    #
    # Translates classified error decisions into formatted HTTP responses.
    module ErrorResponder
      API_ROOT_PATH = '/api/v1'

      class << self
        # Formats and renders an HTTP error response.
        #
        # @param request [Rack::Request]
        # @param response [Rack::Response]
        # @param error [StandardError]
        # @return [String] serialized response body
        def respond(request:, response:, error:)
          decision = ErrorClassifier.classify(error)
          response.status = decision.status
          apply_retry_after(response, decision.status)

          emit_error_event(error, decision)
          write_internal_error_log(request, error)

          return render_plain_error(response, decision) if request_target(request) == RequestTarget::FEED
          if request_target(request) == RequestTarget::API || request.path.to_s.start_with?(API_ROOT_PATH)
            return render_api_error(response, decision)
          end

          render_plain_error(response, decision)
        end

        private

        def apply_retry_after(response, status)
          case status
          when 429 then response['Retry-After'] ||= Flags.rate_limit_window_seconds.to_s
          when 503, 504 then response['Retry-After'] ||= Flags.retry_after_timeout_seconds.to_s
          end
        end

        def render_plain_error(response, decision)
          Feeds::Renderer.render_error(decision.message, response: response)
        end

        def render_api_error(response, decision)
          response['Content-Type'] = 'application/json'
          JSON.generate({ success: false, error: failure_payload(decision) })
        end

        def failure_payload(decision)
          decision.to_h.slice(:code, :message, :kind, :retryable, :next_action, :retry_action)
        end

        def write_internal_error_log(request, error)
          return if error.is_a?(HttpError)

          id = request.env['html2rss.request_context']&.request_id ||
               (request.respond_to?(:get_header) && request.get_header('HTTP_X_REQUEST_ID'))
          request.env['rack.errors']&.puts(id ? "[request_id=#{id}] #{error.message}" : error.message)
        end

        # @param request [#env]
        # @return [Symbol, nil]
        def request_target(request)
          request.env[RequestTarget::ENV_KEY]
        end

        def emit_error_event(error, decision)
          details = {
            error_class: error.class.name,
            error_code: decision.code,
            status: decision.status,
            **ErrorClassifier.extract_diagnostics(error)
          }
          Observability.emit(event_name: 'request.error', outcome: 'failure', level: :error, details: details)
        end
      end
    end
  end
end
