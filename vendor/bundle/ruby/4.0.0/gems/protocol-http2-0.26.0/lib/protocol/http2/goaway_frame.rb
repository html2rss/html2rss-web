# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "frame"

module Protocol
	module HTTP2
		# The GOAWAY frame is used to initiate shutdown of a connection or to signal serious error conditions. GOAWAY allows an endpoint to gracefully stop accepting new streams while still finishing processing of previously established streams. This enables administrative actions, like server maintenance.
		#
		# +-+-------------------------------------------------------------+
		# |R|                  Last-Stream-ID (31)                        |
		# +-+-------------------------------------------------------------+
		# |                      Error Code (32)                          |
		# +---------------------------------------------------------------+
		# |                  Additional Debug Data (*)                    |
		# +---------------------------------------------------------------+
		#
		class GoawayFrame < Frame
			TYPE = 0x7
			FORMAT = "NN"
			
			# Check if this frame applies to the connection level.
			# @returns [Boolean] Always returns true for GOAWAY frames.
			def connection?
				true
			end
			
			# Unpack the GOAWAY frame payload.
			# @returns [Array] Last stream ID, error code, and debug data.
			def unpack
				data = super
				
				last_stream_id, error_code = data.unpack(FORMAT)
				
				return last_stream_id, error_code, data.slice(8, data.bytesize-8)
			end
			
			# Pack GOAWAY frame data into payload.
			# @parameter last_stream_id [Integer] The last processed stream ID.
			# @parameter error_code [Integer] The error code for connection termination.
			# @parameter data [String] Additional debug data.
			def pack(last_stream_id, error_code, data)
				super [last_stream_id, error_code].pack(FORMAT) + data
			end
			
			# Apply this GOAWAY frame to a connection for processing.
			# @parameter connection [Connection] The connection to apply the frame to.
			def apply(connection)
				connection.receive_goaway(self)
			end
		end
	end
end
