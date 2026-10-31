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
          ErrorReporter.report(request:, error:, decision:)

          api_request?(request) ? render_api_error(response, decision) : render_plain_error(response, decision)
        end

        private

        # @param response [Rack::Response]
        # @param status [Integer]
        # @return [void]
        def apply_retry_after(response, status)
          case status
          in 429 then response['Retry-After'] ||= Flags.rate_limit_window_seconds.to_s
          in 503 | 504 then response['Retry-After'] ||= Flags.retry_after_timeout_seconds.to_s
          else nil
          end
        end

        # @param request [Rack::Request]
        # @return [Boolean]
        def api_request?(request)
          case request.env[RequestTarget::ENV_KEY]
          in RequestTarget::FEED then false
          in RequestTarget::API then true
          else request.path.to_s.start_with?(API_ROOT_PATH)
          end
        end

        # @param response [Rack::Response]
        # @param decision [ErrorClassifier::Decision]
        # @return [String]
        def render_plain_error(response, decision) = Feeds::Renderer.render_error(decision.message, response:)

        # @param response [Rack::Response]
        # @param decision [ErrorClassifier::Decision]
        # @return [String]
        def render_api_error(response, decision)
          response['Content-Type'] = 'application/json'
          payload = decision.to_h.slice(:code, :message, :kind, :retryable, :next_action, :retry_action)
          JSON.generate({ success: false, error: payload })
        end
      end
    end
  end
end
