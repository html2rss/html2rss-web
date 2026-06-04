# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http/error"

module Protocol
	module WebSocket
		# Represents an error that occurred during the WebSocket protocol negotiation or communication.
		# Status codes as defined by <https://tools.ietf.org/html/rfc6455#section-7.4.1>.
		class Error < HTTP::Error
			# Indicates a normal closure, meaning that the purpose for which the connection was established has been fulfilled.
			NO_ERROR = 1000
			
			# Indicates that an endpoint is "going away", such as a server going down or a browser having navigated away from a page.
			GOING_AWAY = 1001
			
			# Indicates that an endpoint is terminating the connection due to a protocol error.
			PROTOCOL_ERROR = 1002
			
			# Indicates that an endpoint is terminating the connection because it has received a type of data it cannot accept. (e.g., an endpoint that understands only text data MAY send this if it receives a binary message).
			INVALID_DATA = 1003
			
			
			# Indicates that an endpoint is terminating the connection because it has received data within a message that was not consistent with the type of the message (e.g., non-UTF-8 data within a text message).
			INVALID_PAYLOAD = 1007
			
			# Indicates that an endpoint is terminating the connection because it has received a message that violates its policy. This is a generic status code that can be returned when there is no other more suitable status code (e.g., 1003 or 1009) or if there is a need to hide specific details about the policy.
			POLICY_VIOLATION = 1008
			
			# Indicates that an endpoint is terminating the connection because it has received a message that is too big for it to process.
			MESSAGE_TOO_LARGE = 1009
			
			# Indicates that an endpoint (client) is terminating the connection because it has expected the server to negotiate one or more extension, but the server didn't return them in the response message of the WebSocket handshake. The list of extensions that are needed should appear in the /reason/ part of the Close frame. Note that this status code is not used by the server, because it can fail the WebSocket handshake instead.
			MISSING_EXTENSION = 1010
			
			# Indicates that a server is terminating the connection because it encountered an unexpected condition that prevented it from fulfilling the request.
			INTERNAL_ERROR = 1011
		end
		
		# Raised by stream or connection handlers, results in GOAWAY frame which signals termination of the current connection. You *cannot* recover from this exception, or any exceptions subclassed from it.
		class ProtocolError < Error
			# Initialize a protocol error with an optional status code.
			# @parameter message [String] The error message.
			# @parameter code [Integer] The WebSocket status code associated with the error.
			def initialize(message, code = PROTOCOL_ERROR)
				super(message)
				
				@code = code
			end
			
			# @attribute [Integer] The status code associated with the error.
			attr :code
		end
		
		# The connection was closed, maybe unexpectedly.
		class ClosedError < ProtocolError
		end
		
		# When the frame payload does not match expectations.
		class FrameSizeError < ProtocolError
		end
	end
end
