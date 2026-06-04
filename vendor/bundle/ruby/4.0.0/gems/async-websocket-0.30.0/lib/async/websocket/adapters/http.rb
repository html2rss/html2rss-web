# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2024, by Samuel Williams.
# Copyright, 2021, by Aurora Nockert.

require_relative "../connection"
require_relative "../response"

require "protocol/websocket/extensions"

module Async
	module WebSocket
		module Adapters
			module HTTP
				include ::Protocol::WebSocket::Headers
				
				def self.websocket?(request)
					Array(request.protocol).any? { |e| e.casecmp?(PROTOCOL) }
				end
				
				def self.open(request, headers: [], protocols: [], handler: Connection, extensions: ::Protocol::WebSocket::Extensions::Server.default, **options, &block)
					if websocket?(request)
						headers = Protocol::HTTP::Headers[headers]
						
						# Select websocket sub-protocol:
						if requested_protocol = request.headers[SEC_WEBSOCKET_PROTOCOL]
							protocol = (requested_protocol & protocols).first
						end
						
						if extensions and extension_headers = request.headers[SEC_WEBSOCKET_EXTENSIONS]
							extensions.accept(extension_headers) do |header|
								headers.add(SEC_WEBSOCKET_EXTENSIONS, header.join(";"))
							end
						end
						
						response = Response.for(request, headers, protocol: protocol, **options) do |stream|
							framer = Protocol::WebSocket::Framer.new(stream)
							connection = handler.call(framer, protocol, extensions)
							
							yield connection
						ensure
							connection&.close
							stream.close
						end
						
						# Once we get to this point, we no longer need to hold on to the request:
						request = nil
						
						return response
					end
				end
			end
		end
	end
end
