# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Centralized error rendering for API and XML endpoints.
    #
    # Keeping this mapping in one place ensures consistent status codes and
    # content types without duplicating rescue behavior in routes.
    module ErrorResponder
      API_ROOT_PATH = '/api/v1'
      INTERNAL_ERROR_CODE = Api::V1::Contract::CODES[:internal_server_error]

      class << self
        # @param request [Rack::Request]
        # @param response [Rack::Response]
        # @param error [StandardError]
        # @return [String] serialized JSON or XML error body.
        def respond(request:, response:, error:)
          error_code = resolve_error_code(error)
          response.status = resolve_status(error)
          emit_error_event(error, error_code, response.status)
          write_internal_error_log(request, error)

          client_message = client_message_for(error)

          return render_feed_error(request, response, client_message) if RequestTarget.feed?(request)
          return render_api_error(response, client_message, error_code) if api_request?(request)

          render_xml_error(response, client_message)
        end

        private

        # @param request [Rack::Request]
        # @return [Boolean]
        def api_request?(request)
          RequestTarget.api?(request) || api_path?(request)
        end

        # @param request [Rack::Request]
        # @return [Boolean]
        def api_path?(request)
          path = request.path.to_s
          path == API_ROOT_PATH || path.start_with?("#{API_ROOT_PATH}/")
        end

        # @param response [Rack::Response]
        # @param message [String]
        # @param code [String]
        # @return [String] JSON error payload.
        def render_api_error(response, message, code)
          response['Content-Type'] = 'application/json'
          JSON.generate({ success: false, error: { message: message, code: code } })
        end

        # @param response [Rack::Response]
        # @param message [String]
        # @return [String] negotiated feed error payload.
        def render_feed_error(request, response, message)
          format = FeedResponseFormat.for_request(request)
          response['Content-Type'] = FeedResponseFormat.content_type(format)
          return JsonFeedBuilder.build_error_feed(message: message) if format == FeedResponseFormat::JSON_FEED

          XmlBuilder.build_error_feed(message: message)
        end

        # @param response [Rack::Response]
        # @param message [String]
        # @return [String] XML error feed.
        def render_xml_error(response, message)
          response['Content-Type'] = 'application/xml'
          XmlBuilder.build_error_feed(message: message)
        end

        # @param request [Rack::Request]
        # @param error [StandardError]
        # @return [String]
        def error_log_line(request, error)
          request_id_header = request.respond_to?(:get_header) ? request.get_header('HTTP_X_REQUEST_ID') : nil
          context = request.env['html2rss.request_context']
          request_id = request_id_header || context&.request_id
          return error.message unless request_id

          "[request_id=#{request_id}] #{error.message}"
        end

        # @param error [StandardError]
        # @return [String]
        def resolve_error_code(error)
          error.respond_to?(:code) ? error.code : INTERNAL_ERROR_CODE
        end

        # @param error [StandardError]
        # @return [Integer]
        def resolve_status(error)
          error.respond_to?(:status) ? error.status : 500
        end

        # @param error [StandardError]
        # @return [String]
        def client_message_for(error)
          error.is_a?(Html2rss::Web::HttpError) ? error.message : Html2rss::Web::HttpError::DEFAULT_MESSAGE
        end

        # @param request [Rack::Request]
        # @param error [StandardError]
        # @return [void]
        def write_internal_error_log(request, error)
          return if error.is_a?(Html2rss::Web::HttpError)

          request.env['rack.errors']&.puts(error_log_line(request, error))
        end

        # @param error [StandardError]
        # @param error_code [String]
        # @param status [Integer]
        # @return [void]
        def emit_error_event(error, error_code, status)
          Observability.emit(
            event_name: 'request.error',
            outcome: 'failure',
            details: { error_class: error.class.name, error_code: error_code, status: status },
            level: :error
          )
        end
      end
    end
  end
end
