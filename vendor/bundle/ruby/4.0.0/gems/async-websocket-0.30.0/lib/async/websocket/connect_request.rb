# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2023, by Thomas Morgan.

require "protocol/http/request"
require "protocol/http/headers"
require "protocol/websocket/headers"
require "protocol/http/body/readable"

require "async/variable"

module Async
	module WebSocket
		# This is required for HTTP/2 to establish a connection using the WebSocket protocol.
		# See https://tools.ietf.org/html/rfc8441 for more details.
		class ConnectRequest < ::Protocol::HTTP::Request
			include ::Protocol::WebSocket::Headers
			
			class Wrapper
				def initialize(stream, response)
					@response = response
					@stream = stream
				end
				
				def close
					@response.close
				end
				
				def unwrap
					@response.buffered!
				end
				
				attr_accessor :response
				attr_accessor :stream
				
				def stream?
					@response.success? and @stream
				end
				
				def status
					@response.status
				end
				
				def headers
					@response.headers
				end
			end
			
			class Hijack < Protocol::HTTP::Body::Readable
				def initialize(request)
					@request = request
					@stream = Async::Variable.new
				end
				
				def stream?
					true
				end
				
				def stream
					@stream.value
				end
				
				def call(stream)
					@stream.resolve(stream)
				end
			end
			
			def initialize(request, protocols: [], version: 13, &block)
				body = Hijack.new(self)
				
				headers = ::Protocol::HTTP::Headers[request.headers]
				
				headers.add(SEC_WEBSOCKET_VERSION, String(version))
				
				if protocols.any?
					headers.add(SEC_WEBSOCKET_PROTOCOL, protocols.join(","))
				end
				
				super(request.scheme, request.authority, ::Protocol::HTTP::Methods::CONNECT, request.path, nil, headers, body, PROTOCOL)
			end
			
			def call(connection)
				response = super
				
				Wrapper.new(@body.stream, response)
			end
		end
	end
end
