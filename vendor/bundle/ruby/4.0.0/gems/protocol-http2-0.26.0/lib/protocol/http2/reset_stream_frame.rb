# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "frame"

module Protocol
	module HTTP2
		NO_ERROR = 0
		PROTOCOL_ERROR = 1
		INTERNAL_ERROR = 2
		FLOW_CONTROL_ERROR = 3
		TIMEOUT = 4
		STREAM_CLOSED = 5
		FRAME_SIZE_ERROR = 6
		REFUSED_STREAM = 7
		CANCEL = 8
		COMPRESSION_ERROR = 9
		CONNECT_ERROR = 10
		ENHANCE_YOUR_CALM = 11
		INADEQUATE_SECURITY = 12
		HTTP_1_1_REQUIRED = 13
		
		# The RST_STREAM frame allows for immediate termination of a stream. RST_STREAM is sent to request cancellation of a stream or to indicate that an error condition has occurred.
		#
		# +---------------------------------------------------------------+
		# |                        Error Code (32)                        |
		# +---------------------------------------------------------------+
		#
		class ResetStreamFrame < Frame
			TYPE = 0x3
			FORMAT = "N".freeze
			
			# Unpack the error code from the frame payload.
			# @returns [Integer] The error code.
			def unpack
				@payload.unpack1(FORMAT)
			end
			
			# Pack an error code into the frame payload.
			# @parameter error_code [Integer] The error code to pack.
			def pack(error_code = NO_ERROR)
				@payload = [error_code].pack(FORMAT)
				@length = @payload.bytesize
			end
			
			# Apply this RST_STREAM frame to a connection for processing.
			# @parameter connection [Connection] The connection to apply the frame to.
			def apply(connection)
				connection.receive_reset_stream(self)
			end
			
			# Read and validate the RST_STREAM frame payload.
			# @parameter stream [IO] The stream to read from.
			# @raises [FrameSizeError] If the frame length is invalid.
			def read_payload(stream)
				super
				
				if @length != 4
					raise FrameSizeError, "Invalid frame length"
				end
			end
		end
	end
end
