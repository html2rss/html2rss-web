# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Centralized error rendering for API and XML endpoints.
    module ErrorResponder # rubocop:disable Metrics/ModuleLength
      API_ROOT_PATH = '/api/v1'
      INTERNAL_ERROR_CODE = InternalServerError::CODE
      NETWORK_ERRORS = Set[
        Timeout::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError,
        EOFError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
      ].freeze

      AUTH_META = { kind: 'auth', retryable: false, next_action: 'enter_token', retry_action: 'none' }.freeze
      INPUT_META = { kind: 'input', retryable: false, next_action: 'correct_input', retry_action: 'none' }.freeze
      SERVER_META = { kind: 'server', retryable: false, next_action: 'none', retry_action: 'none' }.freeze
      RETRY_META = { retryable: true, next_action: 'retry', retry_action: 'primary' }.freeze

      class << self # rubocop:disable Metrics/ClassLength
        # @param request [Rack::Request]
        # @param response [Rack::Response]
        # @param error [StandardError]
        # @return [String]
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def respond(request:, response:, error:)
          decision = ErrorClassifier.classify(error)
          status = resolve_status(error, decision)
          code = resolve_error_code(error, decision)
          response.status = status

          if status == 429
            response['Retry-After'] ||= Flags.rate_limit_window_seconds.to_s
          elsif [503, 504].include?(status)
            response['Retry-After'] ||= Flags.retry_after_timeout_seconds.to_s
          end

          emit_error_event(error, code, response.status)
          write_internal_error_log(request, error)

          return render_feed_error(request, response, error, decision) if request_target(request) == RequestTarget::FEED
          if request_target(request) == RequestTarget::API || request.path.to_s.start_with?(API_ROOT_PATH)
            return render_api_error(request, response, error, decision)
          end

          render_xml_error(response, error, decision)
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        private

        def render_feed_error(request, response, error, decision)
          f = FeedResponseFormat.for_request(request)
          response['Content-Type'] = FeedResponseFormat.content_type(f)
          msg = client_message_for(error, decision)
          return JsonFeedBuilder.build_error_feed(message: msg) if f == FeedResponseFormat::JSON_FEED

          XmlBuilder.build_error_feed(message: msg)
        end

        def render_api_error(_request, response, error, decision)
          response['Content-Type'] = 'application/json'
          JSON.generate({ success: false, error: failure_payload(error, decision) })
        end

        def render_xml_error(response, error, decision)
          response['Content-Type'] = 'application/xml'
          XmlBuilder.build_error_feed(message: client_message_for(error, decision))
        end

        def resolve_error_code(error, decision)
          return decision.code if decision

          case error
          when ->(e) { server_timeout?(e) } then ServiceUnavailableError::CODE
          when ->(e) { gateway_timeout?(e) } then GatewayTimeoutError::CODE
          else error.respond_to?(:code) ? error.code : INTERNAL_ERROR_CODE
          end
        end

        def resolve_status(error, decision)
          return decision.status if decision

          case error
          when TooManyRequestsError then 429
          when ServiceUnavailableError, ->(e) { server_timeout?(e) } then 503
          when GatewayTimeoutError, ->(e) { gateway_timeout?(e) } then 504
          else error.respond_to?(:status) ? error.status : 500
          end
        end

        def client_message_for(error, decision)
          return decision.message if decision

          case error
          when TooManyRequestsError then 'Too many requests. Please wait before retrying.'
          when ServiceUnavailableError, ->(e) { server_timeout?(e) }
            'The server is too busy or the request timed out. Please try again later.'
          when GatewayTimeoutError, ->(e) { gateway_timeout?(e) }
            'The target website took too long to respond. Please try again later.'
          else
            error.is_a?(HttpError) ? error.message : HttpError::DEFAULT_MESSAGE
          end
        end

        def failure_payload(error, decision)
          { message: client_message_for(error, decision), code: resolve_error_code(error, decision) }
            .merge(failure_metadata(error, decision))
        end

        def failure_metadata(error, decision)
          return decision_metadata(decision) if decision
          return AUTH_META if error.is_a?(UnauthorizedError)
          return INPUT_META if error.is_a?(BadRequestError) || error.is_a?(ForbiddenError)
          return SERVER_META if error.is_a?(HealthCheckFailedError)

          RETRY_META.merge(kind: error_kind(error))
        end

        # @param decision [Html2rss::Web::ErrorClassifier::Decision]
        # @return [Hash{Symbol=>Object}]
        def decision_metadata(decision)
          {
            kind: decision.kind,
            retryable: decision.retryable,
            next_action: decision.next_action,
            retry_action: decision.retry_action
          }
        end

        def error_kind(error)
          if error.is_a?(TooManyRequestsError)
            'client'
          elsif error.is_a?(GatewayTimeoutError) || gateway_timeout?(error)
            'network'
          else
            ErrorClassifier.error_chain(error).any? { |e| NETWORK_ERRORS.include?(e.class) } ? 'network' : 'server'
          end
        end

        def server_timeout?(error)
          defined?(::Rack::Timeout::RequestTimeoutException) && error.is_a?(::Rack::Timeout::RequestTimeoutException)
        end

        def gateway_timeout?(error)
          error.is_a?(Timeout::Error) || error.is_a?(Errno::ETIMEDOUT)
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

        def emit_error_event(error, error_code, status)
          Observability.emit(event_name: 'request.error', outcome: 'failure', level: :error,
                             details: { error_class: error.class.name, error_code: error_code, status: status })
        end
      end
    end
  end
end
