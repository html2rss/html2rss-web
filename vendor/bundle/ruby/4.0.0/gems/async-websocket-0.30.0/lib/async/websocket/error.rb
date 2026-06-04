# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/websocket/error"

module Async
	module WebSocket
		class ProtocolError < ::Protocol::WebSocket::ProtocolError
		end
		
		class Error < ::Protocol::WebSocket::Error
		end
		
		class UnsupportedVersionError < Error
		end
		
		class ConnectionError < Error
			def initialize(message, response)
				super(message)
				
				@response = response
			end
			
			# The failed HTTP response.
			attr :response
		end
	end
end
