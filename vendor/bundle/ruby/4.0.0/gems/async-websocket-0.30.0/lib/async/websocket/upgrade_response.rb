# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2023, by Thomas Morgan.

require "async/http/body/hijack"
require "protocol/http/response"
require "protocol/websocket/headers"

module Async
	module WebSocket
		# The response from the server back to the client for negotiating HTTP/1.x WebSockets.
		class UpgradeResponse < ::Protocol::HTTP::Response
			include ::Protocol::WebSocket::Headers
			
			def initialize(request, headers = nil, protocol: nil, &block)
				headers = ::Protocol::HTTP::Headers[headers]
				
				if accept_nounce = request.headers[SEC_WEBSOCKET_KEY]&.first
					headers.add(SEC_WEBSOCKET_ACCEPT, Nounce.accept_digest(accept_nounce))
					
					if protocol
						headers.add(SEC_WEBSOCKET_PROTOCOL, protocol)
					end
					
					body = Async::HTTP::Body::Hijack.wrap(request, &block)
					
					super(request.version, 101, headers, body, PROTOCOL)
				else
					super(request.version, 400, headers)
				end
			end
		end
	end
end
