# frozen_string_literal: true

require 'json'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Size-bounded JSON object reader for create and studio requests.
        module JsonBody
          MAX_BODY_BYTES = 64 * 1024

          class << self
            ##
            # Parses the request body as a JSON object.
            #
            # An empty body is an empty object. A body over {MAX_BODY_BYTES} is rejected
            # before it is parsed. The body is rewound so a later reader can see it.
            #
            # @param request [Rack::Request]
            # @return [Hash]
            # @raise [Html2rss::Web::BadRequestError] when the body is too large or not a JSON object
            def object(request)
              raw = read(request)
              return {} if raw.strip.empty?

              parsed = JSON.parse(raw)
              raise BadRequestError, 'Invalid JSON payload' unless parsed.is_a?(Hash)

              parsed
            rescue JSON::ParserError
              raise BadRequestError, 'Invalid JSON payload'
            end

            ##
            # Rejects a declared content length over {MAX_BODY_BYTES} without reading the body.
            #
            # @param request [Rack::Request]
            # @return [void]
            # @raise [Html2rss::Web::BadRequestError] when Content-Length is over the cap
            def enforce_limit!(request)
              return unless request.content_length.to_i > MAX_BODY_BYTES

              raise BadRequestError, 'Payload too large'
            end

            private

            # @param request [Rack::Request]
            # @return [String]
            def read(request)
              enforce_limit!(request)

              request.body.read(MAX_BODY_BYTES + 1).to_s.tap do |raw|
                request.body.rewind
                raise BadRequestError, 'Payload too large' if raw.bytesize > MAX_BODY_BYTES
              end
            end
          end
        end
      end
    end
  end
end
