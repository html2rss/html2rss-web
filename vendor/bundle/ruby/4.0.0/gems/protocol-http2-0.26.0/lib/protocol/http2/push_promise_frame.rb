# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "frame"
require_relative "padded"
require_relative "continuation_frame"

module Protocol
	module HTTP2
		# The PUSH_PROMISE frame is used to notify the peer endpoint in advance of streams the sender intends to initiate. The PUSH_PROMISE frame includes the unsigned 31-bit identifier of the stream the endpoint plans to create along with a set of headers that provide additional context for the stream.
		# 
		# +---------------+
		# |Pad Length? (8)|
		# +-+-------------+-----------------------------------------------+
		# |R|                  Promised Stream ID (31)                    |
		# +-+-----------------------------+-------------------------------+
		# |                   Header Block Fragment (*)                 ...
		# +---------------------------------------------------------------+
		# |                           Padding (*)                       ...
		# +---------------------------------------------------------------+
		#
		class PushPromiseFrame < Frame
			include Continued, Padded
			
			TYPE = 0x5
			FORMAT = "N".freeze
			
			# Unpack the promised stream ID and header block fragment.
			# @returns [Array] An array containing the promised stream ID and header block data.
			def unpack
				data = super
				
				stream_id = data.unpack1(FORMAT)
				
				return stream_id, data.byteslice(4, data.bytesize - 4)
			end
			
			# Pack the promised stream ID and header block data into the frame.
			# @parameter stream_id [Integer] The promised stream ID.
			# @parameter data [String] The header block data.
			# @parameter arguments [Array] Additional arguments.
			# @parameter options [Hash] Options for packing.
			def pack(stream_id, data, *arguments, **options)
				super([stream_id].pack(FORMAT) + data, *arguments, **options)
			end
			
			# Apply this PUSH_PROMISE frame to a connection for processing.
			# @parameter connection [Connection] The connection to apply the frame to.
			def apply(connection)
				connection.receive_push_promise(self)
			end
		end
	end
end
