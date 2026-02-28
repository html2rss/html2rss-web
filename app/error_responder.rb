# frozen_string_literal: true

require_relative 'api/v1/contract'

module Html2rss
  module Web
    module ErrorResponder
      API_ROOT_PATH = '/api/v1'
      INTERNAL_ERROR_CODE = Api::V1::Contract::CODES[:internal_server_error]

      class << self
        def respond(request:, response:, error:)
          error_code = error.respond_to?(:code) ? error.code : INTERNAL_ERROR_CODE
          response.status = error.respond_to?(:status) ? error.status : 500
          client_message = error.is_a?(HttpError) ? error.message : HttpError::DEFAULT_MESSAGE
          request.env['rack.errors']&.puts(error.message) unless error.is_a?(HttpError)

          return render_api_error(response, client_message, error_code) if api_request?(request)

          render_xml_error(response, client_message)
        end

        private

        def api_request?(request)
          path = request.path.to_s
          path == API_ROOT_PATH || path.start_with?("#{API_ROOT_PATH}/")
        end

        def render_api_error(response, message, code)
          response['Content-Type'] = 'application/json'
          JSON.generate({ success: false, error: { message: message, code: code } })
        end

        def render_xml_error(response, message)
          response['Content-Type'] = 'application/xml'
          XmlBuilder.build_error_feed(message: message)
        end
      end
    end
  end
end
