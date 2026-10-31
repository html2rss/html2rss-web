# frozen_string_literal: true

require 'json'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Size-bounded JSON object reader shared by create and refine requests.
        module JsonBody
          MAX_BYTES = 64 * 1024

          class << self
            ##
            # Parses the request body as a JSON object. An empty body is an empty object.
            # The body is rewound so a later reader can see it.
            #
            # @param request [Rack::Request]
            # @return [Hash{String=>Object}]
            # @raise [Html2rss::Web::BadRequestError] when too large, malformed, or not an object
            def object(request)
              enforce_limit!(request)
              raw = read(request)
              return {} if raw.strip.empty?

              parsed = JSON.parse(raw)
              raise BadRequestError, 'Invalid JSON payload' unless parsed.is_a?(Hash)

              parsed
            rescue JSON::ParserError
              raise BadRequestError, 'Invalid JSON payload'
            end

            ##
            # Rejects a declared content length over {MAX_BYTES} without reading the body.
            #
            # @param request [Rack::Request]
            # @return [void]
            # @raise [Html2rss::Web::BadRequestError]
            def enforce_limit!(request)
              return unless request.content_length.to_i > MAX_BYTES

              raise BadRequestError, 'Payload too large'
            end

            private

            # @param request [Rack::Request]
            # @return [String]
            def read(request)
              request.body.read(MAX_BYTES + 1).to_s.tap do |raw|
                request.body.rewind
                raise BadRequestError, 'Payload too large' if raw.bytesize > MAX_BYTES
              end
            end
          end
        end
      end
    end
  end
end
