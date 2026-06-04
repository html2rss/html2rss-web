# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "protocol/http/error"

module Protocol
	module HTTP2
		# Status codes as defined by <https://tools.ietf.org/html/rfc7540#section-7>.
		class Error < HTTP::Error
			# The associated condition is not a result of an error.  For example, a GOAWAY might include this code to indicate graceful shutdown of a connection.
			NO_ERROR = 0x0
			
			# The endpoint detected an unspecific protocol error.  This error is for use when a more specific error code is not available.
			PROTOCOL_ERROR = 0x1
			
			# The endpoint encountered an unexpected internal error.
			INTERNAL_ERROR = 0x2
			
			# The endpoint detected that its peer violated the flow-control protocol.
			FLOW_CONTROL_ERROR = 0x3
			
			# The endpoint sent a SETTINGS frame but did not receive a response in a timely manner.
			SETTINGS_TIMEOUT = 0x4
			
			# The endpoint received a frame after a stream was half-closed.
			STREAM_CLOSED = 0x5
			
			# The endpoint received a frame with an invalid size.
			FRAME_SIZE_ERROR = 0x6
			
			# The endpoint refused the stream prior to performing any application processing.
			REFUSED_STREAM = 0x7
			
			# Used by the endpoint to indicate that the stream is no longer needed.
			CANCEL = 0x8
			
			# The endpoint is unable to maintain the header compression context for the connection.
			COMPRESSION_ERROR = 0x9
			
			# The connection established in response to a CONNECT request was reset or abnormally closed.
			CONNECT_ERROR = 0xA
			
			# The endpoint detected that its peer is exhibiting a behavior that might be generating excessive load.
			ENHANCE_YOUR_CALM = 0xB
			
			# The underlying transport has properties that do not meet minimum security requirements.
			INADEQUATE_SECURITY = 0xC
			
			# The endpoint requires that HTTP/1.1 be used instead of HTTP/2.
			HTTP_1_1_REQUIRED = 0xD
		end
		
		# Raised if connection header is missing or invalid indicating that
		# this is an invalid HTTP 2.0 request - no frames are emitted and the
		# connection must be aborted.
		class HandshakeError < Error
		end
		
		# Raised by stream or connection handlers, results in GOAWAY frame
		# which signals termination of the current connection. You *cannot*
		# recover from this exception, or any exceptions subclassed from it.
		class ProtocolError < Error
			# Initialize a protocol error with message and error code.
			# @parameter message [String] The error message.
			# @parameter code [Integer] The HTTP/2 error code.
			def initialize(message, code = PROTOCOL_ERROR)
				super(message)
				
				@code = code
			end
			
			attr :code
		end
		
		# Represents an error specific to stream operations.
		class StreamError < ProtocolError
		end
		
		# Represents an error for operations on closed streams.
		class StreamClosed < StreamError
			# Initialize a stream closed error.
			# @parameter message [String] The error message.
			def initialize(message)
				super message, STREAM_CLOSED
			end
		end
		
		# Represents a GOAWAY-related protocol error.
		class GoawayError < ProtocolError
		end
		
		# When the frame payload does not match expectations.
		class FrameSizeError < ProtocolError
			# Initialize a frame size error.
			# @parameter message [String] The error message.
			def initialize(message)
				super message, FRAME_SIZE_ERROR
			end
		end
		
		# Represents a header processing error.
		class HeaderError < StreamClosed
			# Initialize a header error.
			# @parameter message [String] The error message.
			def initialize(message)
				super(message)
			end
		end
		
		# Raised on invalid flow control frame or command.
		class FlowControlError < ProtocolError
			# Initialize a flow control error.
			# @parameter message [String] The error message.
			def initialize(message)
				super message, FLOW_CONTROL_ERROR
			end
		end
	end
end
