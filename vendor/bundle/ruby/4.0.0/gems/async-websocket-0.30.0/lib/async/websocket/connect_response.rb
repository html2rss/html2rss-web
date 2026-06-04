# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http/response"
require "async/http/body/hijack"

module Async
	module WebSocket
		# The response from the server back to the client for negotiating HTTP/2 WebSockets.
		class ConnectResponse < ::Protocol::HTTP::Response
			include ::Protocol::WebSocket::Headers
			
			def initialize(request, headers = nil, protocol: nil, &block)
				headers = ::Protocol::HTTP::Headers[headers]
				
				if protocol
					headers.add(SEC_WEBSOCKET_PROTOCOL, protocol)
				end
				
				# For compatibility with HTTP/1 websockets proxied over HTTP/2, we process the accept nounce here:
				if accept_nounce = request.headers[SEC_WEBSOCKET_KEY]&.first
					headers.add(SEC_WEBSOCKET_ACCEPT, Nounce.accept_digest(accept_nounce))
				end
				
				body = Async::HTTP::Body::Hijack.wrap(request, &block)
				
				super(request.version, 200, headers, body)
			end
		end
	end
end
