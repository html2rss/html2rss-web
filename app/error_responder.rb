# frozen_string_literal: true

require_relative 'api/v1/contract'

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
          error_code = error.respond_to?(:code) ? error.code : INTERNAL_ERROR_CODE
          response.status = error.respond_to?(:status) ? error.status : 500
          client_message = error.is_a?(HttpError) ? error.message : HttpError::DEFAULT_MESSAGE
          request.env['rack.errors']&.puts(error_log_line(request, error)) unless error.is_a?(HttpError)

          return render_api_error(response, client_message, error_code) if api_request?(request)

          render_xml_error(response, client_message)
        end

        private

        # @param request [Rack::Request]
        # @return [Boolean] true when request path is within API v1.
        def api_request?(request)
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
      end
    end
  end
end
